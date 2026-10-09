-- Unit Test Suite for x_player_armor
-- Validates SOLID architecture, registrations, detached inventory logic,
-- defense calculations, formspec v7 generation, and compatibility shims.

local mod_dir = "/Users/juraj/Library/Application Support/minetest/mods/x_player_armor"

-- 1. Setup Mock Luanti Engine
_G.core = {
	features = {test = true},
	create_detached_inventory = true,
	registered_tools = {},
	registered_items = {},
	registered_nodes = {},
	registered_craftitems = {},
	registered_entities = {},
	registered_aliases = {},
	registered_crafts = {},
	registered_lbms = {},
	registered_chatcommands = {},
	detached_inventories = {},
	callbacks = {
		on_joinplayer = {},
		on_leaveplayer = {},
		on_dieplayer = {},
		on_punchplayer = {},
		on_player_hpchange = {},
		on_shutdown = {},
		on_respawnplayer = {},
		on_player_receive_fields = {},
		globalstep = {},
	},
	settings = {
		get = function(self, key) return nil end,
		get_bool = function(self, key, default) return default end,
	},
}
_G.minetest = _G.core

core.registered_globalsteps = core.callbacks.globalstep
core.registered_on_joinplayers = core.callbacks.on_joinplayer
core.registered_on_leaveplayers = core.callbacks.on_leaveplayer
core.registered_on_dieplayers = core.callbacks.on_dieplayer
core.registered_on_respawnplayers = core.callbacks.on_respawnplayer
core.registered_on_punchplayers = core.callbacks.on_punchplayer
core.registered_on_player_hpchanges = core.callbacks.on_player_hpchange
core.registered_on_player_receive_fields = core.callbacks.on_player_receive_fields

if not table.copy then
	function table.copy(t)
		if type(t) ~= "table" then return t end
		local copy = {}
		for k, v in pairs(t) do
			copy[k] = (type(v) == "table" and table.copy(v)) or v
		end
		return copy
	end
end

core.mock_gametime = 100
function core.get_gametime()
	return core.mock_gametime or 100
end

function core.get_player_window_information(_name)
	return {
		size = {x = 1920, y = 1080},
		real_gui_scaling = 1.0,
		hud_scaling = 1.0,
	}
end

function core.get_current_modname()
	return "x_player_armor"
end

function core.get_modpath(name)
	if name == "x_player_armor" then
		return mod_dir
	elseif name == "sfinv" then
		return "/sfinv"
	elseif name == "x_player_api" and _G.x_player_api then
		return "/x_player_api"
	elseif name == "i3" and _G.i3 then
		return "/i3"
	elseif name == "unified_inventory" and _G.unified_inventory then
		return "/unified_inventory"
	end
	return nil
end

_G.sfinv = {
	pages = {},
	contexts = {},
	register_page = function(name, def)
		sfinv.pages[name] = def
	end,
	make_formspec = function(player, context, content, show_inv, size)
		local theme_inv = "list[current_player;main;0,5.2;8,1;]list[current_player;main;0,6.35;8,3;8]"
		return (size or "size[8,9.1]") .. (show_inv and theme_inv or "") .. content
	end,
	get_or_create_context = function(player)
		local name = player:get_player_name()
		if not sfinv.contexts[name] then
			sfinv.contexts[name] = {page = "x_player_armor:armor"}
		end
		return sfinv.contexts[name]
	end,
	set_context = function(player, ctx)
		sfinv.contexts[player:get_player_name()] = ctx
	end,
	get_page = function(player)
		local ctx = sfinv.contexts[player:get_player_name()]
		return ctx and ctx.page or "sfinv:craft"
	end,
	set_player_inventory_formspec = function(player, context)
		local ctx = context or sfinv.get_or_create_context(player)
		local page = sfinv.pages[ctx.page]
		if page and page.get then
			local fs = page:get(player, ctx)
			player:set_inventory_formspec(fs)
		end
	end,
}

function core.get_translator(_name)
	return function(str, ...)
		local args = {...}
		local max_arg = 0
		for idx in str:gmatch("@(%d+)") do
			local n = tonumber(idx)
			if n and n > max_arg then max_arg = n end
		end
		if #args < max_arg then
			error("Not enough arguments provided to core.translate")
		end
		local res = str
		for i = 1, #args do
			res = res:gsub("@" .. i, tostring(args[i]))
		end
		return res
	end
end

function core.colorize(_color, msg)
	return msg
end

function core.get_background_escape_sequence(color)
	return "\27(b@" .. color .. ")"
end

function core.explode_scrollbar_event(str)
	local t, val = str:match("(%w+):(%d+)")
	return {type = t or "VAL", value = tonumber(val) or 0}
end

function core.log(level, msg)
	-- silent in tests unless error
	if level == "error" then
		print("LOG ERROR: " .. tostring(msg))
	end
end

function core.register_tool(name, def)
	local clean_name = name:gsub("^:", "")
	core.registered_tools[clean_name] = def
	core.registered_items[clean_name] = def
end

function core.register_node(name, def)
	local clean_name = name:gsub("^:", "")
	core.registered_nodes[clean_name] = def
	core.registered_items[clean_name] = def
end

function core.register_entity(name, def)
	core.registered_entities[name] = def
end

function core.unregister_item(name)
	if core.registered_items then core.registered_items[name] = nil end
	if core.registered_tools then core.registered_tools[name] = nil end
	if core.registered_nodes then core.registered_nodes[name] = nil end
	if core.registered_craftitems then core.registered_craftitems[name] = nil end
end

function core.register_alias(alias, orig)
	core.registered_aliases[alias] = orig
end

function core.register_alias_force(alias, orig)
	core.unregister_item(alias)
	core.registered_aliases[alias] = orig
end

function core.clear_craft(recipe)
	if not recipe or not recipe.output then return false end
	local target = recipe.output
	local cleared = false
	for i = #core.registered_crafts, 1, -1 do
		local c = core.registered_crafts[i]
		if c.output and (c.output == target or c.output:find("^" .. target .. "%s")) then
			table.remove(core.registered_crafts, i)
			cleared = true
		end
	end
	return cleared
end

function core.get_all_craft_recipes(query)
	if not query or query == "" then return nil end
	local result = {}
	for _, c in ipairs(core.registered_crafts) do
		if c.output and (c.output == query or c.output:find("^" .. query .. "%s")) then
			table.insert(result, c)
		end
	end
	return #result > 0 and result or nil
end

function core.register_craft(def)
	table.insert(core.registered_crafts, def)
end

function core.register_lbm(def)
	table.insert(core.registered_lbms, def)
end

function core.register_chatcommand(name, def)
	core.registered_chatcommands[name] = def
end

function core.register_on_joinplayer(fn)
	table.insert(core.callbacks.on_joinplayer, fn)
end

function core.register_on_leaveplayer(fn)
	table.insert(core.callbacks.on_leaveplayer, fn)
end

function core.register_on_shutdown(fn)
	table.insert(core.callbacks.on_shutdown, fn)
end

function core.register_on_respawnplayer(fn)
	table.insert(core.callbacks.on_respawnplayer, fn)
end

function core.register_on_dieplayer(fn)
	table.insert(core.callbacks.on_dieplayer, fn)
end

function core.register_on_punchplayer(fn)
	table.insert(core.callbacks.on_punchplayer, fn)
end

function core.register_on_player_hpchange(fn)
	table.insert(core.callbacks.on_player_hpchange, fn)
end

function core.register_globalstep(fn)
	table.insert(core.callbacks.globalstep, fn)
end

function core.register_on_player_receive_fields(fn)
	table.insert(core.callbacks.on_player_receive_fields, fn)
end

core.mock_players = {}
function core.get_player_by_name(name)
	return core.mock_players[name]
end

function core.get_connected_players()
	local list = {}
	for _, p in pairs(core.mock_players) do
		table.insert(list, p)
	end
	return list
end

function core.get_item_group(name, group)
	local rname = core.registered_aliases[name] or name
	local def = core.registered_items[rname] or core.registered_nodes[rname] or core.registered_tools[rname]
	return (def and def.groups and def.groups[group]) or 0
end

function core.override_item(name, redefs)
	local def = core.registered_items[name] or core.registered_nodes[name]
	if def then
		for k, v in pairs(redefs) do
			def[k] = v
		end
	end
end

core.callbacks.on_mods_loaded = {}
function core.register_on_mods_loaded(fn)
	table.insert(core.callbacks.on_mods_loaded, fn)
end

core.callbacks.on_player_receive_fields = {}
function core.register_on_player_receive_fields(fn)
	table.insert(core.callbacks.on_player_receive_fields, fn)
end

core.shown_formspecs = {}
function core.show_formspec(name, formname, fs)
	core.shown_formspecs[name] = {formname = formname, formspec = fs}
end

function core.after(delay, fn, ...)
	local unpack_fn = unpack or table.unpack
	local args = {...}
	fn(unpack_fn(args))
end

core.sounds_played = {}
function core.sound_play(name, params)
	table.insert(core.sounds_played, {name = name, params = params})
	return #core.sounds_played
end

function core.is_protected(_pos, _name)
	return false
end

core.player_privs = {}
function core.set_player_privs(name, privs)
	core.player_privs[name] = privs
end

function core.check_player_privs(name, privs)
	local user_privs = core.player_privs[name]
	if not user_privs then return false end
	for priv, val in pairs(privs) do
		if val and not user_privs[priv] then
			return false
		end
	end
	return true
end

function core.hash_node_position(pos)
	return pos.x * 65536 + pos.y * 256 + pos.z
end

function core.add_item(pos, item)
	return nil
end

function core.item_place(itemstack, _placer, _pointed_thing, _param2)
	return itemstack
end

Raycast = function(...)
	return function() return nil end
end

core.nodes = {}
core.node_metas = {}

local function create_mock_inv()
	local lists = {}
	local inv = {lists = lists}
	function inv:get_size(listname) return #(self.lists[listname] or {}) end
	function inv:set_size(listname, size)
		self.lists[listname] = self.lists[listname] or {}
		for i = 1, size do
			self.lists[listname][i] = self.lists[listname][i] or ItemStack("")
		end
	end
	function inv:get_list(listname) return self.lists[listname] end
	function inv:get_stack(listname, idx) return (self.lists[listname] and self.lists[listname][idx]) or ItemStack("") end
	function inv:set_stack(listname, idx, stack)
		self.lists[listname] = self.lists[listname] or {}
		self.lists[listname][idx] = stack
	end
	return inv
end

function core.set_node(pos, node)
	local key = string.format("%d,%d,%d", pos.x, pos.y, pos.z)
	core.nodes[key] = node
end

function core.swap_node(pos, node)
	local key = string.format("%d,%d,%d", pos.x, pos.y, pos.z)
	local existing = core.nodes[key] or {}
	for k, v in pairs(node) do
		existing[k] = v
	end
	core.nodes[key] = existing
end

function core.get_node(pos)
	local key = string.format("%d,%d,%d", pos.x, pos.y, pos.z)
	return core.nodes[key] or {name = "air", param2 = 0}
end

function core.remove_node(pos)
	local key = string.format("%d,%d,%d", pos.x, pos.y, pos.z)
	core.nodes[key] = {name = "air", param2 = 0}
end

function core.get_node_or_nil(pos)
	local key = string.format("%d,%d,%d", pos.x, pos.y, pos.z)
	return core.nodes[key]
end

function core.pos_to_string(p)
	return string.format("%d,%d,%d", p.x, p.y, p.z)
end

function core.find_nodes_in_area(minp, maxp, nodenames)
	local name_set = {}
	if type(nodenames) == "table" then
		for _, n in ipairs(nodenames) do name_set[n] = true end
	elseif type(nodenames) == "string" then
		name_set[nodenames] = true
	end
	local res = {}
	for k, node in pairs(core.nodes) do
		local x, y, z = k:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
		if x and y and z then
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			if x >= minp.x and x <= maxp.x and y >= minp.y and y <= maxp.y and z >= minp.z and z <= maxp.z then
				if name_set[node.name] then
					table.insert(res, {x = x, y = y, z = z})
				end
			end
		end
	end
	return res
end

function core.get_meta(pos)
	local key = string.format("%d,%d,%d", pos.x, pos.y, pos.z)
	if not core.node_metas[key] then
		local strings = {}
		local ints = {}
		local inv = create_mock_inv()
		core.node_metas[key] = {
			get_string = function(_, k) return strings[k] or "" end,
			set_string = function(_, k, v) strings[k] = v end,
			get_int = function(_, k) return ints[k] or 0 end,
			set_int = function(_, k, v) ints[k] = v end,
			get_inventory = function(_) return inv end,
		}
	end
	return core.node_metas[key]
end

core.chat_messages = {}
function core.chat_send_player(name, msg)
	table.insert(core.chat_messages, {name = name, msg = msg})
end

core.spawners = {}
function core.add_particlespawner(def)
	table.insert(core.spawners, def)
	return #core.spawners
end

function core.formspec_escape(str)
	return (str:gsub("%[", "\\["):gsub("%]", "\\]"))
end

function core.facedir_to_dir(facedir)
	return {x = 0, y = 0, z = 1}
end

function core.dir_to_yaw(dir)
	return 0
end

core.entities = {}
function core.add_entity(pos, name)
	local props = {}
	local rdef = core.registered_entities[name]
	if rdef and rdef.initial_properties then
		for k, v in pairs(rdef.initial_properties) do props[k] = v end
	end
	local ent = {
		name = name,
		pos = pos,
		properties = props,
		attachment = nil,
		valid = true,
		yaw = 0,
	}
	local luaent = {name = name, object = ent}
	ent.luaentity = luaent
	function ent:is_valid() return self.valid end
	function ent:is_player() return false end
	function ent:get_pos() return self.pos end
	function ent:set_pos(p) self.pos = p end
	function ent:setpos(p) self.pos = p end
	function ent:set_yaw(y) self.yaw = y end
	function ent:get_yaw() return self.yaw end
	function ent:set_properties(p)
		for k, v in pairs(p) do self.properties[k] = v end
	end
	function ent:get_properties() return self.properties end
	function ent:set_attach(parent, bone, p, rot, forced_visible)
		self.attachment = {
			parent = parent,
			bone = bone,
			pos = p,
			rot = rot,
			forced_visible = forced_visible,
		}
	end
	function ent:set_detach() self.attachment = nil end
	function ent:get_attach()
		if not self.attachment then return nil end
		return self.attachment.parent, self.attachment.bone, self.attachment.pos, self.attachment.rot, self.attachment.forced_visible
	end
	function ent:get_luaentity()
		return self.luaentity
	end
	function ent:remove()
		self.valid = false
		local erdef = core.registered_entities[self.name]
		if erdef and erdef.on_deactivate then
			erdef.on_deactivate(self.luaentity, true)
		end
	end
	function ent:set_armor_groups(g) end
	table.insert(core.entities, ent)
	return ent
end

function core.clear_objects(options)
	local old_entities = core.entities
	core.entities = {}
	for _, e in ipairs(old_entities) do
		if not (e.is_player and e:is_player()) then
			e.valid = false
			local rdef = core.registered_entities[e.name]
			if rdef and rdef.on_deactivate and options and options.mode == "quick" then
				rdef.on_deactivate(e:get_luaentity(), true)
			end
		end
	end
end

function core.get_objects_inside_radius(pos, radius)
	local res = {}
	local r = radius or 0.5
	local r2 = r * r
	for _, e in ipairs(core.entities) do
		if e.valid and e.pos then
			local dx = e.pos.x - pos.x
			local dy = e.pos.y - pos.y
			local dz = e.pos.z - pos.z
			if (dx * dx + dy * dy + dz * dz) <= (r2 + 0.001) then
				table.insert(res, e)
			end
		end
	end
	return res
end

function core.serialize(tbl)
	local parts = {}
	for k, v in pairs(tbl) do
		if type(k) == "number" then
			table.insert(parts, string.format("[%d]=%q", k, tostring(v)))
		else
			table.insert(parts, string.format("[%q]=%q", tostring(k), tostring(v)))
		end
	end
	return "return {" .. table.concat(parts, ",") .. "}"
end

local loadstring = loadstring or load

function core.deserialize(str)
	if not str or str == "" then return nil end
	local fn = loadstring(str)
	if fn then return fn() end
	return nil
end

-- Mock ItemStack
local function create_mock_itemstack(itemstring)
	local name = ""
	local count = 0
	local wear = 0

	if type(itemstring) == "string" and itemstring ~= "" then
		local parts = {}
		for word in itemstring:gmatch("%S+") do
			table.insert(parts, word)
		end
		name = parts[1] or ""
		count = tonumber(parts[2]) or 1
		wear = tonumber(parts[3]) or 0
	elseif type(itemstring) == "table" then
		if itemstring.get_name then
			name = itemstring:get_name()
			count = itemstring:get_count()
			wear = itemstring:get_wear()
		else
			name = itemstring.name or ""
			count = itemstring.count or 1
			wear = itemstring.wear or 0
		end
	end

	local obj = {}
	function obj:get_name() return name end
	function obj:get_count() return count end
	function obj:get_wear() return wear end
	function obj:set_wear(w) wear = w end
	function obj:is_empty() return name == "" or count <= 0 end
	function obj:clear()
		name = ""
		count = 0
		wear = 0
	end
	function obj:add_wear(amount)
		wear = math.min(65535, wear + (amount or 0))
		if wear >= 65535 then
			self:clear()
		end
	end
	function obj:add_wear_by_uses(max_uses)
		if not max_uses or max_uses <= 0 then return end
		local step = math.max(1, math.ceil(65535 / max_uses))
		wear = wear + step
		if wear >= 65535 then
			self:clear()
		end
	end
	function obj:get_definition()
		local rname = core.registered_aliases[name] or name
		return core.registered_tools[rname] or core.registered_items[rname] or {groups = {}}
	end
	function obj:to_string()
		if self:is_empty() then return "" end
		return string.format("%s %d %d", name, count, wear)
	end
	function obj:take_item(n)
		local taken_count = math.min(count, n or 1)
		count = count - taken_count
		local taken = create_mock_itemstack(string.format("%s %d %d", name, taken_count, wear))
		if count <= 0 then name = "" end
		return taken
	end
	return obj
end

_G.ItemStack = create_mock_itemstack

_G.vector = {
	add = function(a, b) return {x = a.x + (type(b) == "number" and b or b.x), y = a.y + (type(b) == "number" and b or b.y), z = a.z + (type(b) == "number" and b or b.z)} end,
	subtract = function(a, b) return {x = a.x - (type(b) == "number" and b or b.x), y = a.y - (type(b) == "number" and b or b.y), z = a.z - (type(b) == "number" and b or b.z)} end,
	multiply = function(a, s) return {x = a.x * s, y = a.y * s, z = a.z * s} end,
	divide = function(a, s) return {x = a.x / s, y = a.y / s, z = a.z / s} end,
	length = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end,
	normalize = function(v)
		local len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
		if len == 0 then return {x = 0, y = 0, z = 0} end
		return {x = v.x / len, y = v.y / len, z = v.z / len}
	end,
	dot = function(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end,
	new = function(x, y, z)
		if type(x) == "table" then
			return {x = x.x, y = x.y, z = x.z}
		end
		return {x = x or 0, y = y or 0, z = z or 0}
	end,
	copy = function(v)
		return {x = v.x, y = v.y, z = v.z}
	end,
}

-- Mock Detached Inventory
function core.create_detached_inventory(name, callbacks, owner)
	local lists = {armor = {}}
	for i = 1, 6 do lists.armor[i] = ItemStack("") end

	local inv = {
		lists = lists,
		callbacks = callbacks,
		owner = owner,
	}

	function inv:get_size(listname) return #(self.lists[listname] or {}) end
	function inv:set_size(listname, size)
		self.lists[listname] = self.lists[listname] or {}
		for i = 1, size do
			self.lists[listname][i] = self.lists[listname][i] or ItemStack("")
		end
	end
	function inv:get_list(listname) return self.lists[listname] end
	function inv:get_stack(listname, idx) return self.lists[listname][idx] or ItemStack("") end
	function inv:set_stack(listname, idx, stack)
		self.lists[listname][idx] = stack
	end

	core.detached_inventories[name] = inv
	return inv
end

function core.get_inventory(loc)
	if loc.type == "detached" then
		return core.detached_inventories[loc.name]
	end
	return nil
end

-- Mock Player
local function create_mock_player(name)
	local meta_storage = {}
	local mock_meta = {
		get_string = function(self, k) return meta_storage[k] or "" end,
		set_string = function(self, k, v) meta_storage[k] = v end,
	}

	local main_list = {}
	for i = 1, 32 do main_list[i] = ItemStack("") end
	local player_inv = {
		get_list = function(self, l) return main_list end,
		room_for_item = function(self, l, item) return true end,
		add_item = function(self, l, item) return ItemStack("") end,
	}

	local player = {
		name = name,
		hp = 20,
		armor_groups = {},
		physics = {},
		pos = {x = 0, y = 10, z = 0},
		breath = 10,
	}

	function player:is_player() return true end
	function player:is_valid() return true end
	function player:get_player_name() return self.name end
	function player:get_hp() return self.hp end
	function player:set_hp(hp) self.hp = hp end
	function player:get_meta() return mock_meta end

	function player:get_inventory() return player_inv end
	function player:get_pos() return self.pos end
	function player:set_pos(p) self.pos = p end
	function player:setpos(p) self.pos = p end
	function player:get_breath() return self.breath end
	function player:set_breath(val) self.breath = val end
	function player:set_armor_groups(groups) self.armor_groups = groups end
	function player:set_physics_override(phys) self.physics = phys end
	player.properties = {textures = {"x_player_armor_character.png"}, mesh = "character.b3d"}
	function player:get_properties() return self.properties end
	function player:set_properties(p) for k, v in pairs(p) do self.properties[k] = v end end
	function player:get_wielded_item() return self.wielded_item or ItemStack("") end
	function player:set_wielded_item(item) self.wielded_item = item end
	function player:get_wield_index() return self.wield_index or 1 end

	function player:set_wield_index(idx) self.wield_index = idx end
	function player:set_inventory_formspec(fs) self.formspec = fs end
	function player:get_inventory_formspec() return self.formspec or "" end
	function player:get_look_dir() return self.look_dir or {x = 0, y = 0, z = 1} end
	function player:set_look_dir(dir) self.look_dir = dir end
	function player:get_eye_offset() return {x = 0, y = 0, z = 0} end
	function player:get_player_control() return self.controls or {} end
	function player:add_velocity(vel)
		self.last_added_velocity = vel
		self.velocity = self.velocity or {x = 0, y = 0, z = 0}
		self.velocity = {x = self.velocity.x + vel.x, y = self.velocity.y + vel.y, z = self.velocity.z + vel.z}
	end

	player.hud_elements = {}
	player.hud_counter = 0
	function player:hud_add(def)
		self.hud_counter = self.hud_counter + 1
		local id = self.hud_counter
		self.hud_elements[id] = {
			hud_elem_type = def.hud_elem_type or def.type,
			position = def.position,
			alignment = def.alignment,
			offset = def.offset,
			scale = def.scale,
			text = def.text,
			z_index = def.z_index,
		}
		return id
	end
	function player:hud_change(id, stat, val)
		if self.hud_elements[id] then
			self.hud_elements[id][stat] = val
		end
	end
	function player:hud_remove(id)
		self.hud_elements[id] = nil
	end
	function player:hud_get(id)
		return self.hud_elements[id]
	end

	core.mock_players[name] = player
	return player
end

function core.get_player_window_information(_name)
	return {
		size = {x = 1920, y = 1080},
		real_hud_scaling = 1.0,
		real_gui_scaling = 1.0,
	}
end

-- 2. Execute Bootstrapper
print(">>> Loading x_player_armor bootstrap init.lua...")
dofile(mod_dir .. "/init.lua")
assert(_G.x_player_armor, "FAIL: x_player_armor global API was not initialized.")
for _, fn in ipairs(core.callbacks.on_mods_loaded) do
	fn()
end
print("OK: init.lua loaded successfully.")

-- 3. Run Test Assertions
local passed = 0
local function test(name, fn)
	local success, err = pcall(fn)
	if success then
		print("  PASS: " .. name)
		passed = passed + 1
	else
		print("  FAIL: " .. name .. " -> " .. tostring(err))
		error(err)
	end
end

print("\n>>> Executing Unit Tests:")

test("Modular Visual Entity Properties (Multiplayer Blueprint)", function()
	local visual_def = core.registered_entities["x_player_armor:visual"]
	assert(visual_def, "x_player_armor:visual must be registered")
	assert(visual_def.on_step == nil, "on_step must be nil for zero server tick overhead")
	assert(visual_def.initial_properties.physical == false, "physical must be false")
	assert(visual_def.initial_properties.collide_with_objects == false, "collide_with_objects must be false")
	assert(visual_def.initial_properties.pointable == false, "pointable must be false")
	assert(visual_def.initial_properties.static_save == false, "static_save must be false")
end)

test("Armor Items Registration Across All Materials", function()
	local mats = {"wood", "cactus", "steel", "bronze", "diamond", "gold", "mithril", "crystal", "nether", "admin"}
	local pieces = {"helmet", "chestplate", "leggings", "boots", "shield"}

	for _, mat in ipairs(mats) do
		for _, piece in ipairs(pieces) do
			local item = "x_player_armor:" .. piece .. "_" .. mat
			local def = core.registered_tools[item]
			assert(def, "Expected tool registration for " .. item)
			assert(def.groups, "Missing groups for " .. item)
			assert(def.groups["armor_material_" .. mat] == 1, "Missing material group on " .. item)
			if piece == "shield" then
				assert(def.groups.shield == 1, "Expected shield = 1 group on " .. item)
			end
		end
	end

	-- Check enhanced shields
	local wood_es = core.registered_tools["x_player_armor:shield_enhanced_wood"]
	assert(wood_es, "Missing enhanced wood shield")
	assert(wood_es.groups.shield == 1, "Enhanced wood shield must have shield = 1 group")
	local cactus_es = core.registered_tools["x_player_armor:shield_enhanced_cactus"]
	assert(cactus_es, "Missing enhanced cactus shield")
	assert(cactus_es.groups.shield == 1, "Enhanced cactus shield must have shield = 1 group")
end)

test("Legacy Aliases & Global Compatibility Layer", function()
	assert(core.registered_aliases["3d_armor:chestplate_steel"] == "x_player_armor:chestplate_steel", "Legacy alias failed")
	assert(core.registered_aliases["shields:shield_steel"] == "x_player_armor:shield_steel", "Legacy shield alias failed")

	assert(_G.armor, "_G.armor global shim must be defined")
	assert(type(_G.armor.get_valid_player) == "function", "_G.armor.get_valid_player must be a function")
	assert(type(_G.armor.set_player_armor) == "function", "_G.armor.set_player_armor must be a function")
	assert(type(_G.armor.update_player_visuals) == "function", "_G.armor.update_player_visuals must be a function")
	assert(type(_G.shields) == "table", "_G.shields global shim must be defined")
end)

test("Detached Inventory Creation & Slot Restrictions", function()
	local player = create_mock_player("test_hero")
	x_player_armor.inventory.init_player_inventory(player)

	local name, inv = x_player_armor.get_valid_player(player)
	assert(name == "test_hero", "Invalid player name returned")
	assert(inv, "Detached inventory not found")
	assert(inv:get_size("armor") == 6, "Inventory size must be 6 slots")

	-- Slot 1 (head): Helmet accepted, chestplate rejected
	local helmet = ItemStack("x_player_armor:helmet_steel")
	local chest = ItemStack("x_player_armor:chestplate_steel")

	local allow_helmet = inv.callbacks.allow_put(inv, "armor", 1, helmet, player)
	assert(allow_helmet == 1, "Helmet should be accepted in slot 1")

	local allow_chest = inv.callbacks.allow_put(inv, "armor", 1, chest, player)
	assert(allow_chest == 0, "Chestplate should be rejected in slot 1")

	-- Slot 2 (torso): Chestplate accepted
	assert(inv.callbacks.allow_put(inv, "armor", 2, chest, player) == 1, "Chestplate should be accepted in slot 2")
end)

test("Defense Calculation & Full-Set Bonus", function()
	local player = create_mock_player("test_hero")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)

	-- Equip 4 pieces of Steel: helmet(10) + chest(15) + legs(12) + boots(8) = 45 base
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_steel"))
	inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_steel"))
	inv:set_stack("armor", 3, ItemStack("x_player_armor:leggings_steel"))
	inv:set_stack("armor", 4, ItemStack("x_player_armor:boots_steel"))

	x_player_armor.set_player_armor(player)
	local def = x_player_armor.get_player_def(player)

	-- 4 matching pieces trigger +10% set bonus: floor(45 * 1.10) = 49
	assert(def.set_bonus == true, "Set bonus should be active for 4 matching pieces")
	assert(def.level == 49, "Expected defense level 49, got: " .. tostring(def.level))
	assert(player.armor_groups.fleshy == 51, "Expected fleshy group 51, got: " .. tostring(player.armor_groups.fleshy))
end)

test("Legacy Metadata Migration and Slot Reconciliation", function()
	local player = create_mock_player("old_timer")
	-- Scrambled legacy 3d_armor inventory (boots in slot 1, chest in 2, helmet in 3, legs in 4)
	local legacy_data = {
		[1] = "3d_armor:boots_mithril 1 126",
		[2] = "3d_armor:chestplate_mithril 1 126",
		[3] = "3d_armor:helmet_mithril 1 126",
		[4] = "3d_armor:leggings_mithril 1 126",
	}
	player:get_meta():set_string("3d_armor_inventory", core.serialize(legacy_data))

	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)

	assert(inv:get_stack("armor", 1):get_name() == "3d_armor:helmet_mithril", "Reconciliation: Helmet must be sorted into Slot 1 (Head)")
	assert(inv:get_stack("armor", 2):get_name() == "3d_armor:chestplate_mithril", "Reconciliation: Chestplate must be sorted into Slot 2 (Torso)")
	assert(inv:get_stack("armor", 3):get_name() == "3d_armor:leggings_mithril", "Reconciliation: Leggings must be sorted into Slot 3 (Legs)")
	assert(inv:get_stack("armor", 4):get_name() == "3d_armor:boots_mithril", "Reconciliation: Boots must be sorted into Slot 4 (Feet)")
end)

test("Formspec v7 & 3D Model Preview Generation", function()
	local player = create_mock_player("preview_hero")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))

	local fs = x_player_armor.ui.get_formspec(player)
	assert(fs:find("formspec_version%[7%]"), "Formspec must specify formspec_version[7]")
	assert(fs:find("model%["), "Formspec must contain 3D model preview element")
	assert(fs:find("0,%-150"), "Formspec must specify angled preview rotation 0,-150")
	assert(fs:find("x_player_armor_preview.glb"), "Formspec model must reference x_player_armor_preview.glb")
	assert(fs:find("x_player_armor_diamond.png"), "Formspec preview texture must use unified 64x32 sheet")
	assert(fs:find("x_player_armor_character.png,blank.png,x_player_armor_diamond.png,blank.png,blank.png,blank.png,blank.png,blank.png,blank.png"), "Formspec must pass 9-material texture string for GLB preview model")
	assert(fs:find("list%[current_player;main;1.4,7.4;8,3;8%]"), "Formspec must render all 3 rows of main inventory")
	assert(fs:find("list%[current_player;main;1.4,11.0;8,1;0%]"), "Formspec must render player hotbar")
	assert(fs:find("hypertext%[5.50,4.25;5.30,2.25;armor_stats;"), "Formspec must include scrollable hypertext stats element")
	assert(fs:find("ARMOR ATTRIBUTES"), "Formspec must include ARMOR ATTRIBUTES in hypertext")
	assert(fs:find("ACTIVE PERKS"), "Formspec must include ACTIVE PERKS in hypertext")
	assert(fs:find("listring"), "Formspec must include listring for shift-click loop")

	-- Test standard shield rendering in preview model (Slot 6: Standard, Slot 7: Tower blank)
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel"))
	local std_shield_fs = x_player_armor.ui.get_formspec(player)
	assert(std_shield_fs:find("x_player_armor_character.png,blank.png,x_player_armor_diamond.png,blank.png,blank.png,blank.png,x_player_armor_steel.png,blank.png,blank.png"), "Standard shield must populate Slot 6 and keep Slot 7 blank")

	-- Test tower shield rendering in preview model (Slot 6: Standard blank, Slot 7: Tower)
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_enhanced_cactus"))
	local tower_shield_fs = x_player_armor.ui.get_formspec(player)
	assert(tower_shield_fs:find("x_player_armor_character.png,blank.png,x_player_armor_diamond.png,blank.png,blank.png,blank.png,blank.png,x_player_armor_shield_enhanced_cactus.png,blank.png"), "Tower shield must populate Slot 7 and keep Slot 6 blank")

	-- Test wielded item rendering in preview model (9th slot)
	inv:set_stack("armor", 5, ItemStack(""))
	core.register_tool("default:sword_steel", {inventory_image = "default_tool_steelsword.png"})
	player.wielded_item = ItemStack("default:sword_steel")
	local wield_fs = x_player_armor.ui.get_formspec(player)
	assert(wield_fs:find("x_player_armor_character.png,blank.png,x_player_armor_diamond.png,blank.png,blank.png,blank.png,blank.png,blank.png,default_tool_steelsword.png"), "Formspec must include wielded item texture in 9th material slot")
end)

test("Armor Stand Node & Entity", function()
	local node_def = core.registered_nodes["x_player_armor:stand"]
	assert(node_def, "Armor stand node must be registered")
	assert(node_def.mesh == "x_player_armor_stand.glb", "Stand node mesh must be x_player_armor_stand.glb")

	local entity_def = core.registered_entities["x_player_armor:stand_entity"]
	assert(entity_def, "Armor stand display entity must be registered")
	assert(entity_def.initial_properties.mesh == "x_player_armor_preview.glb", "Stand entity mesh must be x_player_armor_preview.glb")
	assert(#entity_def.initial_properties.textures == 9, "Stand entity must have 9 texture slots for preview mesh")
	assert(entity_def.on_step == nil, "Stand entity on_step must be nil")
end)

test("sfinv Armor Tab Page Integration", function()
	local page = sfinv.pages["x_player_armor:armor"]
	assert(page, "sfinv armor page must be registered")
	assert(page.title, "sfinv armor page must have a title")

	local player = create_mock_player("sfinv_tester")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))

	local fs = page:get(player, {})
	assert(fs:find("armor_sfinv_preview"), "sfinv formspec must contain 3D model preview element")
	assert(fs:find("x_player_armor_diamond.png"), "sfinv preview texture must use unified 64x32 sheet")
	assert(fs:find("formspec_version%[7%]"), "sfinv formspec must specify formspec_version[7]")
	assert(fs:find("size%[10.5,12.25%]"), "sfinv formspec must provide consistent bottom padding (10.5 x 12.25)")
	assert(fs:find("box%[0.375,0.25;4.40,6.30;#161b22ee%]"), "Preview card must span 2 rows at (0.375, 0.25) with size (4.40, 6.30)")
	assert(fs:find("box%[5.025,0.25;5.10,2.80;#161b22ee%]"), "Equipped slots card must be positioned at (5.025, 0.25) with size (5.10, 2.80)")
	assert(fs:find("box%[5.025,3.30;5.10,3.25;#161b22ee%]"), "Attributes & perks card must be positioned at (5.025, 3.30) with size (5.10, 3.25)")
	assert(fs:find("hypertext%[5.25,3.45;4.65,2.95;armor_stats;"), "sfinv formspec must include scrollable hypertext stats element")
	assert(fs:find("ARMOR ATTRIBUTES"), "sfinv must display ARMOR ATTRIBUTES header")
	assert(fs:find("ACTIVE PERKS"), "sfinv must display ACTIVE PERKS header")
	assert(fs:find("listcolors%[#00000069;#5A5A5A;#141318"), "sfinv formspec must maintain visible slot backgrounds")
	assert(fs:find("list%[current_player;main;0.375,6.875;8,1;0%]"), "sfinv formspec must include player hotbar at y = 6.875")
	assert(fs:find("list%[current_player;main;0.375,8.3125;8,3;8%]"), "sfinv formspec must include main player inventory at y = 8.3125")
	assert(fs:find("listring"), "sfinv formspec must include listring for shift-click loop")

	-- Equip full set with 4 perks (Fire, Water, Feather, Set Bonus)
	inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_admin"))
	inv:set_stack("armor", 3, ItemStack("x_player_armor:leggings_admin"))
	inv:set_stack("armor", 4, ItemStack("x_player_armor:boots_admin"))
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_admin"))
	x_player_armor.set_player_armor(player)

	local ctx = {}
	local full_fs = page:get(player, ctx)
	assert(full_fs:find("Fire Ward"), "Full perk list must include Fire Ward")
	assert(full_fs:find("Water Ward"), "Full perk list must include Water Ward")
	assert(full_fs:find("Feather Fall"), "Full perk list must include Feather Fall")
	assert(full_fs:find("Set Bonus"), "Full perk list must include Set Bonus")
	assert(full_fs:find("Armor Healing"), "Full perk list must include Armor Healing")
	assert(full_fs:find("Healing Ward"), "Full perk list must include Healing Ward")
end)

test("Armor Attributes & Active Perks Hypertext Breakdown (Healing, Shield & Mobility)", function()
	local player = create_mock_player("perk_tester")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)

	-- 1. Unarmored player: 0% Damage Reduction, 0% Armor Healing, no active enchantments
	x_player_armor.set_player_armor(player)
	local pdef_naked = x_player_armor.get_player_def(player)
	local naked_text = x_player_armor.ui.build_stats_hypertext(pdef_naked, player)
	assert(naked_text:find("Armor Healing"), "Naked stats must show Armor Healing")
	assert(naked_text:find("0%%"), "Naked stats must show 0% healing")
	assert(naked_text:find("No active enchantments"), "Naked stats must show no enchantments")

	-- 2. Equip full Gold set (12% heal across 4 pieces, 40 base + 10% set bonus = 44% level)
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_gold"))
	inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_gold"))
	inv:set_stack("armor", 3, ItemStack("x_player_armor:leggings_gold"))
	inv:set_stack("armor", 4, ItemStack("x_player_armor:boots_gold"))
	x_player_armor.set_player_armor(player)

	local pdef_gold = x_player_armor.get_player_def(player)
	assert(pdef_gold.heal == 12, "Gold 4-piece set must provide 12% armor healing")
	assert(pdef_gold.set_bonus == true, "Gold 4-piece set must have set bonus")

	local gold_text = x_player_armor.ui.build_stats_hypertext(pdef_gold, player)
	assert(gold_text:find("Armor Healing"), "Gold stats must include Armor Healing")
	assert(gold_text:find("12%%"), "Gold stats must show 12% healing")
	assert(gold_text:find("Healing Ward"), "Gold stats must include Healing Ward active perk")
	assert(gold_text:find("Set Bonus"), "Gold stats must include Set Bonus")

	-- 3. Equip Gold Shield in slot 5 (adds 3% heal -> 15% total heal, enables Shield Guard & Thorns)
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_gold"))
	x_player_armor.set_player_armor(player)

	local pdef_shield = x_player_armor.get_player_def(player)
	assert(pdef_shield.heal == 15, "Gold set with shield must provide 15% armor healing")
	assert(pdef_shield.has_shield == true, "pdef must report has_shield = true")
	assert(pdef_shield.has_reciprocate == true, "pdef must report has_reciprocate = true")

	local shield_text = x_player_armor.ui.build_stats_hypertext(pdef_shield, player)
	assert(shield_text:find("15%%"), "Stats with shield must show 15% healing")
	assert(shield_text:find("Shield Defense"), "Stats must include Shield Defense in attributes")
	assert(shield_text:find("Shield Guard"), "Perks must include Shield Guard")
	assert(shield_text:find("Thorns"), "Perks must include Thorns reciprocate damage")

	-- 4. Test physics / mobility modifier display
	pdef_shield.speed = 1.15
	pdef_shield.jump = 1.10
	local mob_text = x_player_armor.ui.build_stats_hypertext(pdef_shield, player)
	assert(mob_text:find("Mobility"), "Modified physics must show Mobility attribute")
	assert(mob_text:find("Speed %+15%%"), "Must format speed modifier")
	assert(mob_text:find("Jump %+10%%"), "Must format jump modifier")
	assert(mob_text:find("Swiftness"), "Perks must include Swiftness when speed > 5%")
	assert(mob_text:find("High Jump"), "Perks must include High Jump when jump > 5%")
end)

test("Dual-Format Armor Attachments & Visuals Reconciliation", function()
	local constants = x_player_armor.constants
	assert(constants.ATTACH_TRANSFORMS, "constants.ATTACH_TRANSFORMS must exist")
	assert(constants.ATTACH_TRANSFORMS.glb, "constants.ATTACH_TRANSFORMS.glb must exist")
	assert(constants.ATTACH_TRANSFORMS.b3d, "constants.ATTACH_TRANSFORMS.b3d must exist")

	-- Verify GLB transforms: Head/Torso rot.y = 0 (faces forward in glb), Limbs rot.x = 180, rot.y = 0
	local glb = constants.ATTACH_TRANSFORMS.glb
	assert(glb.head.rot.y == 0, "GLB head rot.y must be 0 to face forward")
	assert(glb.torso.rot.y == 0, "GLB torso rot.y must be 0 to face forward")
	assert(glb.sleeve_l.rot.x == 180 and glb.sleeve_l.rot.y == 0, "GLB sleeve_l rot must be (180, 0, 0)")
	assert(glb.legs_l.rot.x == 180 and glb.legs_l.rot.y == 0, "GLB legs_l rot must be (180, 0, 0)")
	assert(glb.feet_l.rot.x == 180 and glb.feet_l.rot.y == 0, "GLB feet_l rot must be (180, 0, 0)")

	-- Verify B3D transforms: Head/Torso rot.y = 180 (counteracting Body bone yaw), Limbs rot = (180, 180, 0)
	local b3d = constants.ATTACH_TRANSFORMS.b3d
	assert(b3d.head.rot.y == 180, "B3D head rot.y must be 180")
	assert(b3d.torso.rot.y == 180, "B3D torso rot.y must be 180")
	assert(b3d.sleeve_l.rot.x == 180 and b3d.sleeve_l.rot.y == 180, "B3D sleeve_l rot must be (180, 180, 0)")
	assert(b3d.legs_l.rot.x == 180 and b3d.legs_l.rot.y == 180, "B3D legs_l rot must be (180, 180, 0)")
	assert(b3d.feet_l.rot.x == 180 and b3d.feet_l.rot.y == 180, "B3D feet_l rot must be (180, 180, 0)")

	-- Test Visuals update on native B3D player
	local hero = create_mock_player("visual_tester")
	x_player_armor.inventory.init_player_inventory(hero)
	local _, inv = x_player_armor.get_valid_player(hero)

	-- Equip ONLY helmet
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	x_player_armor.visuals.update_player_visuals(hero)

	local hero_ents = x_player_armor.visuals.player_entities["visual_tester"]
	assert(hero_ents, "Player entities map must exist")
	assert(hero_ents.head and #hero_ents.head == 1, "Only head piece must be spawned")
	assert(hero_ents.torso == nil, "Torso must NOT be spawned when only wearing helmet")
	assert(hero_ents.legs == nil, "Legs must NOT be spawned when only wearing helmet")
	assert(hero_ents.feet == nil, "Boots must NOT be spawned when only wearing helmet")
	assert(hero_ents.shield == nil, "Shield must NOT be spawned when only wearing helmet")

	local head_obj = hero_ents.head[1]
	assert(head_obj.attachment.bone == "Head", "Helmet entity must attach to Head bone")
	assert(head_obj.attachment.rot.y == 180, "B3D native player helmet rot.y must be 180")

	-- Test Visuals update with x_player_api GLB and B3D proxies
	local glb_proxy = {
		is_valid = function() return true end,
		get_pos = function() return {x = 0, y = 10, z = 0} end,
	}
	local b3d_proxy = {
		is_valid = function() return true end,
		get_pos = function() return {x = 0, y = 10, z = 0} end,
	}
	_G.x_player_api = {
		get_visual_proxies = function(p)
			return {glb = glb_proxy, b3d = b3d_proxy}
		end,
		get_modern_observers = function() return {modern_client = true} end,
		get_legacy_observers = function() return {legacy_client = true} end,
	}

	-- Equip chestplate as well
	inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_diamond"))
	x_player_armor.visuals.update_player_visuals(hero)

	-- Should have 2 head entities (1 for GLB, 1 for B3D)
	assert(#hero_ents.head == 2, "Expected 2 head entities across dual proxies")
	-- Should have 6 torso entities (torso + sleeve_l + sleeve_r) * 2 proxies = 6
	assert(#hero_ents.torso == 6, "Expected 6 torso entities across dual proxies")

	-- Verify GLB and B3D proxy piece rotations
	local found_glb_head = false
	local found_b3d_head = false
	for _, obj in ipairs(hero_ents.head) do
		if obj.attachment.parent == glb_proxy then
			assert(obj.attachment.rot.y == 0, "GLB head must have 0 Y rotation to face forward")
			found_glb_head = true
		elseif obj.attachment.parent == b3d_proxy then
			assert(obj.attachment.rot.y == 180, "B3D head must rotate 180 degrees around Y")
			found_b3d_head = true
		end
	end
	assert(found_glb_head and found_b3d_head, "Both GLB and B3D proxy head attachments verified")

	-- Clean up
	x_player_armor.visuals.clear_all("visual_tester")
	assert(x_player_armor.visuals.player_entities["visual_tester"] == nil, "clear_all must clean up player table")
	_G.x_player_api = nil
end)

test("SkinsDB 1.8 3D Rig Attachment Transforms & Torso Scaling Calibration", function()
	local constants = x_player_armor.constants
	assert(constants.ATTACH_TRANSFORMS.skinsdb_b3d, "skinsdb_b3d transform presets must exist")
	assert(constants.ATTACH_TRANSFORMS.skinsdb_glb, "skinsdb_glb transform presets must exist")
	assert(constants.ATTACH_TRANSFORMS.skinsdb, "skinsdb alias must exist")

	-- Verify calibrated scaling factors for skinsdb 6.75 torso height & 1.8 outer layers
	local s_b3d = constants.ATTACH_TRANSFORMS.skinsdb_b3d
	assert(s_b3d.torso.scale and s_b3d.torso.scale.y == 1.08, "Torso scale Y must be 1.08 to envelope 6.75 torso")
	assert(s_b3d.torso.scale.x == 1.05, "Torso scale X must be 1.05 to cover jacket overlay")
	assert(s_b3d.sleeve_l.scale and s_b3d.sleeve_l.scale.y == 1.08, "Sleeve L scale Y must be 1.08")
	assert(s_b3d.sleeve_l.scale.x == 1.06, "Sleeve L scale X must be 1.06 to cover sleeve overlay")
	assert(s_b3d.sleeve_r.scale and s_b3d.sleeve_r.scale.y == 1.08, "Sleeve R scale Y must be 1.08")
	assert(s_b3d.sleeve_r.scale.x == 1.06, "Sleeve R scale X must be 1.06 to cover sleeve overlay")

	-- 1. Standard player with character.b3d
	local norm_hero = create_mock_player("norm_player")
	x_player_armor.inventory.init_player_inventory(norm_hero)
	local _, n_inv = x_player_armor.get_valid_player(norm_hero)
	n_inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_steel"))
	x_player_armor.visuals.update_player_visuals(norm_hero)

	local n_ents = x_player_armor.visuals.player_entities["norm_player"]
	assert(n_ents and n_ents.torso, "Torso entities must be spawned for standard player")
	-- Normal character.b3d player uses default 1.0 scaling
	local n_torso_props = n_ents.torso[1]:get_properties()
	assert(n_torso_props.visual_size.y == 1, "Standard player torso visual_size.y must remain 1.0")

	-- 2. Player with skinsdb_3d_armor_character_5.b3d model
	local skin_hero = create_mock_player("skin_player")
	skin_hero:set_properties({mesh = "skinsdb_3d_armor_character_5.b3d"})
	x_player_armor.inventory.init_player_inventory(skin_hero)
	local _, s_inv = x_player_armor.get_valid_player(skin_hero)
	s_inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_steel"))
	x_player_armor.visuals.update_player_visuals(skin_hero)

	local s_ents = x_player_armor.visuals.player_entities["skin_player"]
	assert(s_ents and s_ents.torso, "Torso entities must be spawned for skinsdb player")
	local s_torso_props = s_ents.torso[1]:get_properties()
	assert(s_torso_props.visual_size.y == 1.08, "Skinsdb player torso visual_size.y must be scaled to 1.08")
	assert(s_torso_props.visual_size.x == 1.05, "Skinsdb player torso visual_size.x must be scaled to 1.05")

	-- Check sleeves on skinsdb player
	local s_sleeve_l_props = s_ents.torso[2]:get_properties()
	assert(s_sleeve_l_props.visual_size.y == 1.08, "Skinsdb player sleeve_l visual_size.y must be 1.08")
	assert(s_sleeve_l_props.visual_size.x == 1.06, "Skinsdb player sleeve_l visual_size.x must be 1.06")

	-- 3. Dynamic Model Transition: switching normal player to skinsdb player model
	norm_hero:set_properties({mesh = "skinsdb_3d_armor_character_5.b3d"})
	x_player_armor.visuals.update_player_visuals(norm_hero)
	local transitioned_ents = x_player_armor.visuals.player_entities["norm_player"]
	assert(transitioned_ents and transitioned_ents.torso, "Torso entities must exist after transition")
	local trans_torso_props = transitioned_ents.torso[1]:get_properties()
	assert(trans_torso_props.visual_size.y == 1.08, "Transitioned player torso must automatically respawn with 1.08 scale")

	-- Clean up
	x_player_armor.visuals.clear_all("norm_player")
	x_player_armor.visuals.clear_all("skin_player")
end)

test("Modern Particle Spawners & VFX Particle Sheet Integration", function()
	core.spawners = {}
	local test_pos = {x = 10, y = 2, z = -5}

	-- 1. Test Healing Ward Particles
	local heal_id = x_player_armor.combat.spawn_heal_particles(test_pos)
	assert(heal_id and heal_id > 0, "spawn_heal_particles must return spawner ID")
	local heal_def = core.spawners[#core.spawners]
	assert(heal_def, "Registered spawner definition must exist")

	-- Validate modern structured fields
	assert(heal_def.pos and heal_def.pos.min and heal_def.pos.max, "Must have structured pos table")
	assert(heal_def.vel and heal_def.vel.min and heal_def.vel.max, "Must have structured vel table")
	assert(heal_def.acc and heal_def.acc.min and heal_def.acc.max, "Must have structured acc table")
	assert(heal_def.jitter and heal_def.jitter.min and heal_def.jitter.max, "Must have structured jitter table")
	assert(heal_def.drag and heal_def.drag.min and heal_def.drag.max, "Must have structured drag table")
	assert(heal_def.bounce and heal_def.bounce.min and heal_def.bounce.max, "Must have structured bounce table")
	assert(heal_def.exptime and heal_def.exptime.min and heal_def.exptime.max, "Must have structured exptime table")
	assert(heal_def.size and heal_def.size.min and heal_def.size.max, "Must have structured size table")
	assert(heal_def.glow and heal_def.glow >= 10, "Heal ward particles must have bright glow")
	assert(heal_def.texpool and #heal_def.texpool == 3, "Heal ward texpool must contain 3 frames")

	-- Ensure x_player_armor_icon.png is NEVER used for particles
	for _, entry in ipairs(heal_def.texpool) do
		assert(not entry.name:find("x_player_armor_icon.png"), "x_player_armor_icon.png is forbidden as particle texture")
		assert(entry.name:find("x_player_armor_particles.png"), "Must use x_player_armor_particles.png sheet")
		assert(entry.blend == "add", "Heal sparkles must use additive blending")
	end

	-- Validate legacy client fallbacks
	assert(heal_def.minpos and heal_def.maxpos, "Must populate minpos/maxpos fallback")
	assert(heal_def.minvel and heal_def.maxvel, "Must populate minvel/maxvel fallback")
	assert(heal_def.minacc and heal_def.maxacc, "Must populate minacc/maxacc fallback")
	assert(heal_def.minexptime and heal_def.maxexptime, "Must populate minexptime/maxexptime fallback")
	assert(heal_def.minsize and heal_def.maxsize, "Must populate minsize/maxsize fallback")
	assert(heal_def.texture and heal_def.texture:find("x_player_armor_particles.png"), "Must populate texture fallback")

	-- Validate multiplayer performance optimizations
	assert(heal_def.amount <= 10, "Heal ward particle count must be lean (<= 10)")
	assert(heal_def.time <= 0.25, "Heal ward burst time must be short (<= 0.25s)")
	assert(heal_def.collisiondetection == false, "Heal ward particles must be non-colliding (zero raycasts)")

	-- 2. Test Shield Block Deflection Particles
	local shield_id = x_player_armor.combat.spawn_shield_block_particles(test_pos)
	assert(shield_id and shield_id > 0, "spawn_shield_block_particles must return spawner ID")
	local shield_def = core.spawners[#core.spawners]
	assert(shield_def.collisiondetection == true, "Shield sparks must have collisiondetection enabled")
	assert(shield_def.collision_removal == true, "Shield sparks must enable collision_removal for multiplayer performance")
	assert(shield_def.amount <= 10, "Shield deflection particle count must be lean (<= 10)")
	assert(shield_def.time <= 0.2, "Shield deflection burst time must be short (<= 0.2s)")
	assert(shield_def.glow >= 12, "Shield deflection sparks must glow brightly")
	assert(shield_def.texpool[1].name:find("verticalframe:8:3"), "Frame 3 must be cyan shield flash")
	assert(shield_def.texpool[2].name:find("verticalframe:8:4"), "Frame 4 must be amber spark")

	-- 3. Test Armor Break Particles Across Materials
	-- Steel
	x_player_armor.combat.spawn_armor_break_particles(test_pos, "x_player_armor:chestplate_steel")
	local steel_break = core.spawners[#core.spawners]
	assert(steel_break.texpool[1].name:find("verticalframe:8:5"), "Steel armor break must use frame 5 metal shard")
	assert(steel_break.collisiondetection == true, "Armor shatter must enable collisiondetection")
	assert(steel_break.collision_removal == true, "Armor shatter must enable collision_removal for performance")
	assert(steel_break.amount <= 12, "Armor break particle count must be lean (<= 12)")
	assert(steel_break.time <= 0.25, "Armor break burst time must be short (<= 0.25s)")
	assert(steel_break.acc.min.y == -9.8 and steel_break.acc.max.y == -9.8, "Armor shards must fall with gravity")

	-- Crystal / Diamond
	x_player_armor.combat.spawn_armor_break_particles(test_pos, "x_player_armor:helmet_diamond")
	local crystal_break = core.spawners[#core.spawners]
	assert(crystal_break.texpool[1].name:find("verticalframe:8:6"), "Diamond armor break must use frame 6 crystal shard")
	assert(crystal_break.glow >= 8, "Crystal shards must glow")

	-- Wood / Cactus
	x_player_armor.combat.spawn_armor_break_particles(test_pos, "x_player_armor:boots_wood")
	local wood_break = core.spawners[#core.spawners]
	assert(wood_break.texpool[1].name:find("verticalframe:8:7"), "Wood armor break must use frame 7 wood splinter")

	-- 4. Test Targeted Multiplayer Networking (playername scoping)
	local mock_player = {
		is_player = function() return true end,
		get_player_name = function() return "test_defender" end,
	}
	x_player_armor.combat.spawn_heal_particles(test_pos, mock_player)
	local targeted_heal = core.spawners[#core.spawners]
	assert(targeted_heal.playername == "test_defender", "spawn_heal_particles must populate playername for targeted networking")

	x_player_armor.combat.spawn_shield_block_particles(test_pos, "test_defender")
	local targeted_shield = core.spawners[#core.spawners]
	assert(targeted_shield.playername == "test_defender", "spawn_shield_block_particles must accept string playername")

	x_player_armor.combat.spawn_armor_break_particles(test_pos, "x_player_armor:chestplate_steel", mock_player)
	local targeted_break = core.spawners[#core.spawners]
	assert(targeted_break.playername == "test_defender", "spawn_armor_break_particles must populate playername when player passed")

	x_player_armor.combat.spawn_impact_particles(test_pos, "metal", mock_player)
	local targeted_impact = core.spawners[#core.spawners]
	assert(targeted_impact.playername == "test_defender", "spawn_impact_particles must populate playername when player passed")
	assert(targeted_impact.glow == 8, "Metal impact particles must have glow = 8")

	x_player_armor.combat.spawn_impact_particles(test_pos, "crystal")
	local crystal_impact = core.spawners[#core.spawners]
	assert(crystal_impact.glow == 12, "Crystal impact particles must have glow = 12")

	x_player_armor.combat.spawn_impact_particles(test_pos, "wood")
	local wood_impact = core.spawners[#core.spawners]
	assert(wood_impact.glow == 4, "Wood impact particles must have glow = 4")

	-- 5. Test Universal spawn_particles Factory Fallback Population
	local custom_def = {
		amount = 5,
		time = 1,
		pos = {min = {x = 0, y = 0, z = 0}, max = {x = 1, y = 1, z = 1}},
		vel = {min = {x = -1, y = 0, z = -1}, max = {x = 1, y = 2, z = 1}},
		texpool = {{name = "x_player_armor_particles.png^[verticalframe:8:0"}},
	}
	x_player_armor.combat.spawn_particles(custom_def)
	assert(custom_def.minpos and custom_def.maxpos, "Custom def must have minpos/maxpos populated")
	assert(custom_def.minvel and custom_def.maxvel, "Custom def must have minvel/maxvel populated")
	assert(custom_def.texture == "x_player_armor_particles.png^[verticalframe:8:0", "Custom def texture fallback set from texpool")

	-- 6. Test SOLID Architecture Separation (x_player_armor.vfx)
	assert(x_player_armor.vfx, "x_player_armor.vfx subsystem must be initialized")
	assert(x_player_armor.vfx.spawn_particles == x_player_armor.combat.spawn_particles, "combat.spawn_particles must delegate to vfx.spawn_particles")
	assert(x_player_armor.vfx.spawn_heal_particles == x_player_armor.combat.spawn_heal_particles, "combat.spawn_heal_particles must delegate to vfx.spawn_heal_particles")
	assert(x_player_armor.vfx.spawn_shield_block_particles == x_player_armor.combat.spawn_shield_block_particles, "combat.spawn_shield_block_particles must delegate to vfx.spawn_shield_block_particles")
	assert(x_player_armor.vfx.spawn_armor_break_particles == x_player_armor.combat.spawn_armor_break_particles, "combat.spawn_armor_break_particles must delegate to vfx.spawn_armor_break_particles")
	assert(x_player_armor.vfx.spawn_impact_particles == x_player_armor.combat.spawn_impact_particles, "combat.spawn_impact_particles must delegate to vfx.spawn_impact_particles")
end)

test("Environmental Effects Multiplayer Optimization & Idle-Skipping", function()
	local diver = create_mock_player("diver_dan")
	x_player_armor.inventory.init_player_inventory(diver)
	local _, inv = x_player_armor.get_valid_player(diver)

	-- 1. Without water armor, active_water_players must be empty
	x_player_armor.set_player_armor(diver)
	assert(not x_player_armor.effects.active_water_players["diver_dan"], "Player without water armor must not be in active_water_players")

	-- 2. Run globalstep when active_water_players is empty: must idle-skip
	local effects_step = core.callbacks.globalstep[1]
	assert(effects_step, "Globalstep callback must be registered")
	diver.breath = 5
	effects_step(1.5)
	assert(diver.breath == 5, "Idle-skipping globalstep must not touch players when active registry is empty")

	-- 3. Equip armor with armor_water group
	core.register_tool("x_player_armor:test_diving_helmet", {
		description = "Diving Helmet",
		inventory_image = "x_player_armor_test.png",
		groups = {armor_head = 1, armor_water = 2, armor_uses = 100},
	})
	inv:set_stack("armor", 1, ItemStack("x_player_armor:test_diving_helmet"))
	x_player_armor.set_player_armor(diver)
	assert(x_player_armor.effects.active_water_players["diver_dan"] == 2, "Active water players registry must track diver with water=2")

	-- 4. Globalstep replenishment when submerged (breath < 10)
	diver.breath = 5
	effects_step(1.5)
	assert(diver.breath == 7, "Globalstep must replenish breath by water rating (5 + 2 = 7)")

	-- Full breath (10): set_breath not called unnecessarily
	diver.breath = 10
	effects_step(1.5)
	assert(diver.breath == 10, "Full breath remains unchanged")

	-- 5. Unequip: removed from active registry
	inv:set_stack("armor", 1, ItemStack(""))
	x_player_armor.set_player_armor(diver)
	assert(not x_player_armor.effects.active_water_players["diver_dan"], "Unequipping must remove player from active registry")

	-- 6. Player disconnect cleanup
	inv:set_stack("armor", 1, ItemStack("x_player_armor:test_diving_helmet"))
	x_player_armor.set_player_armor(diver)
	assert(x_player_armor.effects.active_water_players["diver_dan"] == 2, "Re-equipping adds player back")
	for _, fn in ipairs(core.callbacks.on_leaveplayer) do
		fn(diver)
	end
	assert(not x_player_armor.effects.active_water_players["diver_dan"], "on_leaveplayer must purge player from active registry")

	-- 7. Tiered fire protection thresholds (5, 3, 2, 1) matching 3d_armor
	local c_fire = x_player_armor.constants.FIRE_NODES
	-- Validate Tier 5 (Lava)
	assert(c_fire["default:lava_source"] == 5, "default:lava_source must be Tier 5")
	assert(c_fire["default:lava_flowing"] == 5, "default:lava_flowing must be Tier 5")
	assert(c_fire["nether:lava_source"] == 5, "nether:lava_source must be Tier 5")

	-- Validate Tier 3 (Flames)
	assert(c_fire["fire:basic_flame"] == 3, "fire:basic_flame must be Tier 3")
	assert(c_fire["fire:permanent_flame"] == 3, "fire:permanent_flame must be Tier 3")

	-- Validate Tier 2 (Hazardous Flora / Crusts)
	assert(c_fire["ethereal:crystal_spike"] == 2, "ethereal:crystal_spike must be Tier 2")
	assert(c_fire["ethereal:fire_flower"] == 2, "ethereal:fire_flower must be Tier 2")
	assert(c_fire["nether:lava_crust"] == 2, "nether:lava_crust must be Tier 2")

	-- Validate Tier 1 (Torches)
	assert(c_fire["default:torch"] == 1, "default:torch must be Tier 1")
	assert(c_fire["default:torch_ceiling"] == 1, "default:torch_ceiling must be Tier 1")
	assert(c_fire["default:torch_wall"] == 1, "default:torch_wall must be Tier 1")

	-- Validate _G.armor compatibility shim
	assert(_G.armor and _G.armor.fire_nodes == c_fire, "_G.armor.fire_nodes must reference constants.FIRE_NODES")

	-- 8. Runtime Tiered Mitigation in on_player_hpchange
	core.register_tool("x_player_armor:test_fire_t1", {
		description = "Tier 1 Fire Gear",
		inventory_image = "x_player_armor_test.png",
		groups = {armor_head = 1, armor_fire = 1, armor_uses = 100},
	})
	core.register_tool("x_player_armor:test_fire_t3", {
		description = "Tier 3 Fire Gear",
		inventory_image = "x_player_armor_test.png",
		groups = {armor_torso = 1, armor_fire = 3, armor_uses = 100},
	})
	core.register_tool("x_player_armor:test_fire_t5", {
		description = "Tier 5 Fire Gear",
		inventory_image = "x_player_armor_test.png",
		groups = {armor_shield = 1, armor_fire = 5, armor_uses = 100},
	})

	local hpchange_fn = core.callbacks.on_player_hpchange[1]
	assert(hpchange_fn, "on_player_hpchange callback must exist")

	-- Test with Tier 1 (fire = 1):
	inv:set_stack("armor", 1, ItemStack("x_player_armor:test_fire_t1"))
	x_player_armor.set_player_armor(diver)
	assert(diver.armor_def and diver.armor_def.fire == 1 or x_player_armor.get_player_def(diver).fire == 1, "Player must have fire=1")

	-- Torch (Tier 1): 1 >= 1 -> 0 (Immune)
	assert(hpchange_fn(diver, -1, {type = "node_damage", node = "default:torch"}) == 0, "Tier 1 must negate torch damage")

	-- Flames (Tier 3): 1 < 3 -> Partial mitigation: -6 * (1 - 1/3) = -4
	local flame_t1 = hpchange_fn(diver, -6, {type = "node_damage", node = "fire:basic_flame"})
	assert(flame_t1 == -4, "Partial mitigation must reduce -6 flame damage to -4 (got " .. tostring(flame_t1) .. ")")

	-- Test with Tier 3 (fire = 3):
	inv:set_stack("armor", 1, ItemStack(""))
	inv:set_stack("armor", 2, ItemStack("x_player_armor:test_fire_t3"))
	x_player_armor.set_player_armor(diver)

	-- Torch (Tier 1): 3 >= 1 -> 0 (Immune)
	assert(hpchange_fn(diver, -1, {type = "node_damage", node = "default:torch_wall"}) == 0, "Tier 3 must negate torch")
	-- Nether crust (Tier 2): 3 >= 2 -> 0 (Immune)
	assert(hpchange_fn(diver, -2, {type = "node_damage", node = "nether:lava_crust"}) == 0, "Tier 3 must negate nether lava crust")
	-- Ethereal fire flower (Tier 2): 3 >= 2 -> 0 (Immune)
	assert(hpchange_fn(diver, -2, {type = "node_damage", node = "ethereal:fire_flower"}) == 0, "Tier 3 must negate ethereal fire flower")
	-- Basic Flame (Tier 3): 3 >= 3 -> 0 (Immune)
	assert(hpchange_fn(diver, -4, {type = "node_damage", node = "fire:basic_flame"}) == 0, "Tier 3 must negate basic flame")
	-- Permanent Flame (Tier 3): 3 >= 3 -> 0 (Immune)
	assert(hpchange_fn(diver, -4, {type = "node_damage", node = "fire:permanent_flame"}) == 0, "Tier 3 must negate permanent flame")

	-- Lava (Tier 5): 3 < 5 -> Partial mitigation: -10 * (1 - 3/5) = -4
	local lava_t3 = hpchange_fn(diver, -10, {type = "node_damage", node = "default:lava_source"})
	assert(lava_t3 == -4, "Partial mitigation with fire=3 must reduce -10 lava damage to -4")

	-- Test with Tier 5 (fire = 5):
	inv:set_stack("armor", 2, ItemStack(""))
	inv:set_stack("armor", 3, ItemStack("x_player_armor:test_fire_t5"))
	x_player_armor.set_player_armor(diver)

	-- Full Lava Source & Flowing (Tier 5): 5 >= 5 -> 0 (Immune)
	assert(hpchange_fn(diver, -8, {type = "node_damage", node = "default:lava_source"}) == 0, "Tier 5 must negate default:lava_source")
	assert(hpchange_fn(diver, -8, {type = "node_damage", node = "default:lava_flowing"}) == 0, "Tier 5 must negate default:lava_flowing")
	assert(hpchange_fn(diver, -8, {type = "node_damage", node = "nether:lava_source"}) == 0, "Tier 5 must negate nether:lava_source")

	-- 9. Dynamic group fallback for unlisted custom mod nodes
	core.register_node("custom_mod:acidic_magma", {
		description = "Acidic Magma",
		groups = {lava = 1, liquid = 2},
	})
	assert(hpchange_fn(diver, -8, {type = "node_damage", node = "custom_mod:acidic_magma"}) == 0, "Tier 5 fire armor must negate unlisted custom node with group:lava")

	core.register_node("custom_mod:cursed_fire", {
		description = "Cursed Fire",
		groups = {igniter = 2},
	})
	assert(hpchange_fn(diver, -5, {type = "node_damage", node = "custom_mod:cursed_fire"}) == 0, "Tier 5 fire armor must negate unlisted custom node with group:igniter")

	-- 10. Drowning negation check
	inv:set_stack("armor", 1, ItemStack("x_player_armor:test_diving_helmet"))
	x_player_armor.set_player_armor(diver)
	local drown_result = hpchange_fn(diver, -2, {type = "drown"})
	assert(drown_result == 0, "Drown damage must be negated event-driven")

	-- Clean up
	inv:set_stack("armor", 1, ItemStack(""))
	inv:set_stack("armor", 2, ItemStack(""))
	inv:set_stack("armor", 3, ItemStack(""))
	x_player_armor.set_player_armor(diver)
end)

test("DRY Utilities Subsystem (x_player_armor.utils)", function()
	assert(x_player_armor.utils, "x_player_armor.utils must be initialized")
	local utils = x_player_armor.utils

	-- 1. copy_table
	local original = {a = 1, b = "hello", c = {nested = true}}
	local shallow = utils.copy_table(original)
	assert(shallow ~= original, "copy_table must return a new table reference")
	assert(shallow.a == 1 and shallow.b == "hello", "copy_table must preserve keys and values")
	shallow.a = 99
	assert(original.a == 1, "Modifying shallow copy must not mutate original top-level keys")

	-- Convenience alias on public API table
	assert(x_player_armor.copy_table == utils.copy_table, "x_player_armor.copy_table must alias utils.copy_table")
	local alias_copy = x_player_armor.copy_table(original)
	assert(alias_copy.b == "hello", "x_player_armor.copy_table must function identically")

	-- 2. deep_copy
	local deep = utils.deep_copy(original)
	assert(deep ~= original, "deep_copy must return a new table reference")
	assert(deep.c ~= original.c, "deep_copy must copy nested tables recursively")
	assert(deep.c.nested == true, "deep_copy must preserve nested values")
	deep.c.nested = false
	assert(original.c.nested == true, "Modifying deep copy nested table must not mutate original nested table")

	-- 3. get_player_name
	assert(utils.get_player_name("raw_name") == "raw_name", "get_player_name must return string directly")
	local mock = {
		is_player = function() return true end,
		get_player_name = function() return "sam_guard" end,
	}
	assert(utils.get_player_name(mock) == "sam_guard", "get_player_name must resolve ObjectRef")
	assert(utils.get_player_name(nil) == nil, "get_player_name must return nil for nil")

	-- 4. get_item_material
	assert(utils.get_item_material("x_player_armor:chestplate_steel") == "steel", "Must extract steel material")
	assert(utils.get_item_material("x_player_armor:helmet_diamond") == "diamond", "Must extract diamond material")
	assert(utils.get_item_material("x_player_armor:boots_wood") == "wood", "Must extract wood material")
	assert(utils.get_item_material("unknown:item") == nil, "Must return nil for unregistered items")
end)

test("Item Durability by Uses & Engine add_wear_by_uses", function()
	local warrior = create_mock_player("test_warrior")
	x_player_armor.inventory.init_player_inventory(warrior)
	local _, inv = x_player_armor.get_valid_player(warrior)

	-- 1. Verify item definitions use modern armor_uses without legacy armor_use
	local bronze_def = core.registered_tools["x_player_armor:chestplate_bronze"]
	assert(bronze_def, "Bronze chestplate must be registered")
	assert(bronze_def.groups.armor_uses == 450, "armor_uses must be 450")
	assert(bronze_def.groups.armor_use == nil, "armor_use must not be set")

	-- 2. Equip item and apply wear with uses = 10
	local test_stack = ItemStack("x_player_armor:chestplate_bronze")
	inv:set_stack("armor", 2, test_stack)

	local destroyed = x_player_armor.combat.damage_item(warrior, 2, test_stack, 10)
	assert(destroyed == false, "Single hit on 10-uses item must not destroy it")
	local worn_stack = inv:get_stack("armor", 2)
	assert(worn_stack:get_wear() > 0, "Item wear must have increased")

	-- 3. Damage until broken (remaining 9 hits)
	for _ = 1, 9 do
		local current = inv:get_stack("armor", 2)
		destroyed = x_player_armor.combat.damage_item(warrior, 2, current, 10)
	end
	assert(destroyed == true, "Item must be destroyed after 10 uses")
	assert(inv:get_stack("armor", 2):is_empty(), "Armor inventory slot must be cleared upon destruction")
end)

test("Dynamic Wield Item Tracking & Formspec UI Update", function()
	-- Register test items with inventory_image and node tiles
	core.register_tool("default:sword_mithril", {inventory_image = "default_tool_mithrilsword.png"})
	core.register_node("default:wood_planks", {
		type = "node",
		tiles = {"default_wood_planks.png"},
	})

	local adventurer = create_mock_player("test_adventurer")
	-- 1. Initialize player and join
	for _, fn in ipairs(core.callbacks.on_joinplayer) do
		fn(adventurer)
	end
	assert(x_player_armor.ui.player_wield["test_adventurer"] ~= nil, "Player wield state must be tracked on join")

	local _, inv = x_player_armor.get_valid_player(adventurer)
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))

	-- 2. Configure sfinv context on the armor page
	sfinv.set_context(adventurer, {page = "x_player_armor:armor"})
	x_player_armor.ui.sfinv_open_players["test_adventurer"] = true
	sfinv.set_player_inventory_formspec(adventurer)
	local initial_fs = adventurer:get_inventory_formspec()
	assert(initial_fs:find("x_player_armor_character.png,blank.png,x_player_armor_diamond.png,blank.png,blank.png,blank.png,blank.png,blank.png,blank.png"), "Initial preview must have blank.png for empty hand")

	-- 3. Player switches hotbar slot to mithril sword
	adventurer:set_wield_index(2)
	adventurer.wielded_item = ItemStack("default:sword_mithril")

	-- Trigger wield change check
	local changed = x_player_armor.ui.check_wield_change(adventurer)
	assert(changed == true, "check_wield_change must return true when wield item/slot changes")

	local sword_fs = adventurer:get_inventory_formspec()
	assert(sword_fs:find("default_tool_mithrilsword.png"), "Inventory formspec must immediately contain wielding sword texture")
	assert(sword_fs:find("x_player_armor_character.png,blank.png,x_player_armor_diamond.png,blank.png,blank.png,blank.png,blank.png,blank.png,default_tool_mithrilsword.png"), "9th material slot must be updated with active sword")

	-- 4. Globalstep monitoring: switch to wooden planks
	adventurer:set_wield_index(3)
	adventurer.wielded_item = ItemStack("default:wood_planks")

	local ui_step = core.callbacks.globalstep[2]
	assert(ui_step, "UI globalstep must be registered at index 2")
	ui_step(0.25) -- Trigger throttled interval

	local wood_fs = adventurer:get_inventory_formspec()
	assert(wood_fs:find("default_wood_planks.png"), "UI globalstep must refresh formspec with node tile")
	assert(wood_fs:find("x_player_armor_character.png,blank.png,x_player_armor_diamond.png,blank.png,blank.png,blank.png,blank.png,blank.png,default_wood_planks.png"), "9th material slot must be updated with node tile")

	-- 5. Switch back to bare hands
	adventurer:set_wield_index(1)
	adventurer.wielded_item = ItemStack("")
	ui_step(0.25)
	local bare_fs = adventurer:get_inventory_formspec()
	assert(bare_fs:find("x_player_armor_character.png,blank.png,x_player_armor_diamond.png,blank.png,blank.png,blank.png,blank.png,blank.png,blank.png"), "Formspec must revert to blank.png when hands are empty")

	-- 6. sfinv on_enter hook guarantees fresh wield state when tab is opened
	adventurer:set_wield_index(2)
	adventurer.wielded_item = ItemStack("default:sword_mithril")
	local page = sfinv.pages["x_player_armor:armor"]
	assert(page.on_enter, "sfinv armor page must define on_enter callback")
	page:on_enter(adventurer, {})
	local enter_fs = page:get(adventurer, {})
	assert(enter_fs:find("default_tool_mithrilsword.png"), "sfinv on_enter and get must render fresh wield item")

	-- 7. Standalone show_armor_formspec
	x_player_armor.ui.show_armor_formspec(adventurer)
	assert(x_player_armor.ui.open_players["test_adventurer"] == true, "Player must be tracked in open_players")

	-- 8. Player disconnect cleanup
	for _, fn in ipairs(core.callbacks.on_leaveplayer) do
		fn(adventurer)
	end
	assert(x_player_armor.ui.player_wield["test_adventurer"] == nil, "Player wield state must be cleaned up on disconnect")
	assert(x_player_armor.ui.open_players["test_adventurer"] == nil, "Player open state must be cleaned up on disconnect")
end)

test("Armor Damage Absorption Feedback, Wear & VFX on Zero-HP Punch", function()
	local defender = create_mock_player("test_tank")
	local attacker = create_mock_player("test_hitter")
	x_player_armor.inventory.init_player_inventory(defender)
	local _, inv = x_player_armor.get_valid_player(defender)

	-- 1. Equip full diamond armor + diamond shield
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_diamond"))
	inv:set_stack("armor", 3, ItemStack("x_player_armor:leggings_diamond"))
	inv:set_stack("armor", 4, ItemStack("x_player_armor:boots_diamond"))
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_diamond"))

	x_player_armor.effects.update_player_armor(defender)

	-- Verify all initial armor items have 0 wear
	for idx = 1, 5 do
		assert(inv:get_stack("armor", idx):get_wear() == 0, "Armor slot " .. idx .. " must start with 0 wear")
	end

	-- Prepare attacker wielding a sword
	attacker:set_wield_index(1)
	attacker.wielded_item = ItemStack("default:sword_mithril")
	core.registered_tools["default:sword_mithril"].tool_capabilities = {
		full_punch_interval = 1.0,
		max_drop_level = 1,
		groupcaps = {snappy = {times = {0.5}, uses = 50, maxlevel = 1}},
		damage_groups = {fleshy = 8},
	}

	core.sounds_played = {}
	local spawner_count_before = #core.spawners

	-- 2. Punch defender with damage = 0 (100% damage absorption by armor)
	x_player_armor.combat.handle_punch(defender, attacker, 1.0, nil, {x = 0, y = 0, z = 1}, 0)

	-- Verify all 5 armor pieces received wear damage even with damage == 0
	for idx = 1, 5 do
		local stack = inv:get_stack("armor", idx)
		assert(stack:get_wear() > 0, "Armor slot " .. idx .. " must take wear damage when absorbing 0-HP damage")
	end

	-- Verify sound was played
	assert(#core.sounds_played > 0, "Combat impact sound must be played when armor absorbs 0-HP damage")

	-- Verify shield block particle effect was spawned
	assert(#core.spawners > spawner_count_before, "VFX particle spawner must be triggered on damage absorption")

	-- Verify attacker weapon received reciprocated wear
	assert(attacker:get_wielded_item():get_wear() == 100, "Attacker weapon must take reciprocated wear")

	-- 3. Test armor deflection without shield (spawns material impact particles)
	inv:set_stack("armor", 5, ItemStack("")) -- Remove shield
	x_player_armor.effects.update_player_armor(defender)

	core.sounds_played = {}
	spawner_count_before = #core.spawners
	local chest_wear_before = inv:get_stack("armor", 2):get_wear()

	-- Punch defender wearing diamond armor without shield with damage = 0
	x_player_armor.combat.handle_punch(defender, attacker, 1.0, nil, {x = 0, y = 0, z = 1}, 0)

	assert(inv:get_stack("armor", 2):get_wear() > chest_wear_before, "Chestplate wear must increase after second punch")
	assert(#core.sounds_played > 0, "Impact sound must play for armor hit")
	assert(core.sounds_played[#core.sounds_played].name == x_player_armor.constants.SOUNDS.hit_crystal, "Crystal impact sound must play for diamond armor")

	local impact_spawner = core.spawners[#core.spawners]
	assert(#core.spawners > spawner_count_before, "Impact particlespawner must be created for body armor deflection")
	assert(impact_spawner.glow == 12, "Diamond/crystal deflection particles must have radiant glow = 12")

	-- 4. Test wooden armor material sound & particles on 0 damage absorption
	inv:set_stack("armor", 1, ItemStack(""))
	inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_wood"))
	inv:set_stack("armor", 3, ItemStack(""))
	inv:set_stack("armor", 4, ItemStack(""))
	x_player_armor.effects.update_player_armor(defender)

	core.sounds_played = {}
	spawner_count_before = #core.spawners

	x_player_armor.combat.handle_punch(defender, attacker, 1.0, nil, {x = 0, y = 0, z = 1}, 0)
	assert(inv:get_stack("armor", 2):get_wear() > 0, "Wooden armor must take wear on 0-damage punch")
	assert(core.sounds_played[#core.sounds_played].name == x_player_armor.constants.SOUNDS.hit_wood, "Wood impact sound must play for wooden armor")
	assert(core.spawners[#core.spawners].glow == 4, "Wood impact particles must have glow = 4")

	-- 5. Test naked player punch with damage = 0 (no armor wear, no sounds, no sparks)
	inv:set_stack("armor", 2, ItemStack(""))
	x_player_armor.effects.update_player_armor(defender)

	core.sounds_played = {}
	spawner_count_before = #core.spawners

	x_player_armor.combat.handle_punch(defender, attacker, 1.0, nil, {x = 0, y = 0, z = 1}, 0)
	assert(#core.sounds_played == 0, "Naked player punch with 0 damage must not play armor sounds")
	assert(#core.spawners == spawner_count_before, "Naked player punch with 0 damage must not spawn armor particles")
end)

test("Legacy 3d_armor Global Shim & Dual Syntax Parity", function()
	local player = create_mock_player("compat_tester")
	x_player_armor.inventory.init_player_inventory(player)

	-- Verify both colon and dot call conventions work identically
	-- 1. Equip via armor.equip (dot syntax)
	local helmet_stack = ItemStack("3d_armor:helmet_steel")
	local ret1 = armor.equip(player, helmet_stack)
	assert(ret1 ~= nil, "armor.equip via dot syntax must succeed")
	assert(armor.get_weared_armor_elements(player).head == true, "Head element must be marked as worn")

	-- 2. Equip via armor:equip (colon syntax)
	local chest_stack = ItemStack("3d_armor:chestplate_steel")
	local ret2 = armor:equip(player, chest_stack)
	assert(ret2 ~= nil, "armor:equip via colon syntax must succeed")
	assert(armor:get_weared_armor_elements(player).torso == true, "Torso element must be marked as worn via colon call")

	-- 3. Check serialize_inventory_list
	local _, inv = x_player_armor.get_valid_player(player)
	local serialized_table = armor.serialize_inventory_list(player, inv:get_list("armor"))
	assert(type(serialized_table) == "table", "serialize_inventory_list must return a table")
	assert(serialized_table[1] ~= nil, "Slot 1 serialized string must exist")

	-- 4. Unequip via armor:unequip (colon syntax)
	local unequipped = armor:unequip(player, "head")
	assert(unequipped:get_name() == "x_player_armor:helmet_steel" or unequipped:get_name() == "3d_armor:helmet_steel",
		"Unequipped head item should be steel helmet")
	assert(armor.get_weared_armor_elements(player).head == nil, "Head element must be cleared after unequip")

	-- 5. armor:remove_all(player)
	armor:remove_all(player)
	local worn_after = armor.get_weared_armor_elements(player)
	assert(next(worn_after) == nil, "All worn armor elements must be cleared after remove_all")
end)

test("HUD Statbar (hbarmor) Wear and State Synchronization", function()
	local player = create_mock_player("hud_tester")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)

	-- Equip 2 damaged pieces: helmet with 1000 wear, chest with 2000 wear
	local h = ItemStack("x_player_armor:helmet_steel")
	h:set_wear(1000)
	local c = ItemStack("x_player_armor:chestplate_steel")
	c:set_wear(2000)
	inv:set_stack("armor", 1, h)
	inv:set_stack("armor", 2, c)

	x_player_armor.set_player_armor(player)

	-- hbarmor reads armor.def[name].state and count
	local name = player:get_player_name()
	local def = armor.def[name]
	assert(def ~= nil, "armor.def must provide player definition")
	assert(def.state == 3000, "def.state must equal total wear (3000), got: " .. tostring(def.state))
	assert(def.count == 2, "def.count must equal 2 worn pieces, got: " .. tostring(def.count))

	-- Unregistered player fallback metatable test
	local ghost_def = armor.def["offline_player_xyz"]
	assert(ghost_def ~= nil, "Fallback metatable must return table for offline player")
	assert(ghost_def.state == 0, "Default state must be 0")
	assert(ghost_def.groups.fleshy == 0, "Default groups fallback must return 0 without error")
end)

test("Shields Compatibility & Dynamic Custom Registration", function()
	assert(_G.shields ~= nil, "Global shields table must exist")
	assert(type(_G.shields.register_shield) == "function", "shields.register_shield must be a function")

	-- Register custom shield using shields API
	shields:register_shield("custom_shield_obsidian", {
		description = "Obsidian Shield",
		inventory_image = "custom_shield.png",
		groups = {armor_shield = 25, armor_heal = 5, armor_use = 500},
	})

	assert(core.registered_tools["custom_shield_obsidian"] ~= nil, "Shield must be registered in core.registered_tools")
	local def = core.registered_tools["custom_shield_obsidian"]
	assert(def.groups.armor_shield == 25, "Shield armor group preserved")
	assert(def.groups.armor_uses == 500, "armor_use translated to armor_uses")
	assert(def.groups.shield == 1, "Shield item must have shield = 1 group for x_player_api block action")
end)

test("Cursed Item Inventory Lock Enforcement", function()
	local player = create_mock_player("cursed_user")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)

	-- Register a cursed helmet
	core.registered_tools["mymod:cursed_crown"] = {
		description = "Cursed Crown",
		groups = {armor_head = 10, cursed = 1},
	}

	local cursed_item = ItemStack("mymod:cursed_crown")
	inv:set_stack("armor", 1, cursed_item)

	-- allow_take callback should reject removing cursed item
	local allowed = inv.callbacks.allow_take(inv, "armor", 1, cursed_item, player)
	assert(allowed == 0, "Taking a cursed armor piece must be prohibited (return 0)")
end)

test("3d_armor_stand Compatibility Shim", function()
	assert(_G["3d_armor_stand"] ~= nil, "3d_armor_stand global table must exist")
	assert(type(_G["3d_armor_stand"].update_entity) == "function", "update_entity must be exported on 3d_armor_stand")
end)

test("Strict Zero-Dependency on x_player_bridge", function()
	assert(core.get_modpath("x_player_bridge") == nil, "x_player_bridge must NOT be registered or required")
	assert(_G.x_player_bridge == nil, "Global x_player_bridge must not exist")
end)

test("Shield Left-Hand Attachment via x_player_api Subsystem", function()
	local attached_items = {}
	local removed_players = {}
	local mock_player = create_mock_player("shield_hero")

	_G.x_player_api = {
		enable_wield_item = true,
		enable_left_wield_first_person = false,
		left_wield_entities = {},
		attach_left_wield_item = function(player, item_or_stack, opts)
			local pname = player:get_player_name()
			attached_items[pname] = {
				item = item_or_stack,
				opts = opts,
			}
			return {
				is_valid = function() return true end,
				get_luaentity = function() return {name = "x_player_api:wield_item"} end,
			}
		end,
		remove_left_wield_item = function(player)
			local pname = player:get_player_name()
			removed_players[pname] = true
			attached_items[pname] = nil
		end,
		set_left_wield_first_person = function(player, val)
			local pname = player:get_player_name()
			_G.x_player_api.left_wield_entities[pname] = {first_person = val}
		end,
		get_left_wield_first_person = function(player)
			local pname = player:get_player_name()
			local data = _G.x_player_api.left_wield_entities[pname]
			if data and data.first_person ~= nil then
				return data.first_person
			end
			return _G.x_player_api.enable_left_wield_first_person == true
		end,
		register_equip_sound = function() end,
		register_item_action = function() end,
		register_blocking_predicate = function() end,
		register_on_state_change = function() end,
	}

	x_player_armor.compat_x_player_api.init()
	assert(x_player_armor.compat_x_player_api.is_present() == true, "x_player_api must be recognized as present")

	-- 1. Direct attach_shield as wielditem (x_player_armor:shield_steel)
	x_player_armor.compat_x_player_api.attach_shield(mock_player, "x_player_armor:shield_steel")
	local record = attached_items["shield_hero"]
	assert(record ~= nil, "attach_left_wield_item must be invoked")
	assert(record.opts.visual == "wielditem", "opts.visual must be 'wielditem' for shield attachments")
	assert(record.item == "x_player_armor:shield_steel", "item must match shield item name")
	assert(record.opts.override_transform == true, "opts.override_transform must be true for forearm attachment")
	assert(record.opts.pos_glb ~= nil and record.opts.pos_glb.y == 5.0, "opts.pos_glb.y must be 5.0 on forearm")
	assert(record.opts.rot_glb ~= nil and record.opts.rot_glb.x == 180, "opts.rot_glb.x must be 180")
	assert(record.opts.pos_b3d ~= nil and record.opts.pos_b3d.y == 5.0, "opts.pos_b3d.y must be 5.0 on forearm")
	assert(record.opts.rot_b3d ~= nil and record.opts.rot_b3d.x == 180, "opts.rot_b3d.x must be 180")

	-- 1b. Shield offset API getters and setters
	local def_glb_offset = x_player_armor.get_shield_offset("glb")
	assert(def_glb_offset.pos.y == 5.0, "get_shield_offset('glb') pos.y must be 5.0")
	assert(def_glb_offset.rot.x == 180, "get_shield_offset('glb') rot.x must be 180")

	x_player_armor.set_shield_offset("glb", {x = -1.0, y = 2.7, z = -3.2}, {x = 180, y = 50, z = 0})
	local updated_offset = x_player_armor.get_shield_offset("glb")
	assert(updated_offset.pos.y == 2.7, "Updated offset y must be 2.7")
	assert(updated_offset.rot.y == 50, "Updated rot y must be 50")
	-- Reset to default
	x_player_armor.set_shield_offset("glb", {x = -0.8, y = 5.0, z = -2.8}, {x = 180, y = 45, z = 0})

	-- 2. 1st-person view configuration toggle
	x_player_armor.compat_x_player_api.set_shield_first_person(mock_player, true)
	assert(x_player_armor.compat_x_player_api.get_shield_first_person(mock_player) == true, "1st person must be true after set")
	x_player_armor.compat_x_player_api.attach_shield(mock_player, "x_player_armor:shield_steel")
	assert(attached_items["shield_hero"].opts.first_person == true, "opts.first_person must be true when enabled for player")

	-- 3. Third-party shield item as wielditem
	core.register_tool("thirdparty_mod:wooden_shield", {
		description = "Wooden Shield",
		inventory_image = "wooden_shield.png",
		groups = {armor_shield = 10},
	})
	x_player_armor.compat_x_player_api.attach_shield(mock_player, "thirdparty_mod:wooden_shield")
	local tp_record = attached_items["shield_hero"]
	assert(tp_record.opts.visual == "wielditem", "Third party shield must use visual = 'wielditem'")

	-- 4. Visuals reconciliation: Slot 5 equipped delegates to attach_shield
	x_player_armor.inventory.init_player_inventory(mock_player)
	local _, inv = x_player_armor.get_valid_player(mock_player)
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel"))
	x_player_armor.visuals.update_player_visuals(mock_player)

	assert(attached_items["shield_hero"] ~= nil, "Slot 5 shield equip must trigger attach_shield")
	local p_ents = x_player_armor.visuals.player_entities["shield_hero"]
	assert(p_ents.shield == nil, "Native x_player_armor visual entity must NOT be created when x_player_api is handling shield")

	-- 5. Unequip shield triggers remove_shield
	inv:set_stack("armor", 5, ItemStack(""))
	removed_players["shield_hero"] = nil
	x_player_armor.visuals.update_player_visuals(mock_player)
	assert(removed_players["shield_hero"] == true, "Empty Slot 5 must trigger remove_shield")

	-- 6. clear_all triggers remove_shield
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel"))
	x_player_armor.visuals.update_player_visuals(mock_player)
	removed_players["shield_hero"] = nil
	x_player_armor.visuals.clear_all("shield_hero")
	assert(removed_players["shield_hero"] == true, "visuals.clear_all must trigger remove_shield")

	-- Cleanup
	_G.x_player_api = nil
	x_player_armor.compat_x_player_api.init()
end)

test("Shield Left-Hand Fallback When x_player_api is Absent (Zero-Wield Invariant)", function()
	-- Ensure x_player_api is absent
	_G.x_player_api = nil
	x_player_armor.compat_x_player_api.init()
	assert(x_player_armor.compat_x_player_api.is_present() == false, "x_player_api must be absent")

	local player = create_mock_player("fallback_hero")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)

	-- 1. Direct call to attach_shield returns nil and creates zero entities
	local ret = x_player_armor.compat_x_player_api.attach_shield(player, "x_player_armor:shield_steel")
	assert(ret == nil, "attach_shield must return nil when x_player_api is absent")

	-- 2. Equip shield in Slot 5 and update visuals: x_player_armor does NOT show or manage wield item entities
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel"))
	x_player_armor.visuals.update_player_visuals(player)

	local hero_ents = x_player_armor.visuals.player_entities["fallback_hero"]
	assert(hero_ents ~= nil, "Player entities map must exist")
	assert(hero_ents.shield == nil, "x_player_armor must NOT show or manage wield item entities when x_player_api is absent")

	x_player_armor.visuals.clear_all("fallback_hero")
end)

test("Shield 1st-Person Visibility Global and World Configuration", function()
	-- Mock x_player_api with enable_left_wield_first_person = true (default is true)
	_G.x_player_api = {
		enable_wield_item = true,
		enable_left_wield_first_person = true,
		left_wield_entities = {},
		attach_left_wield_item = function(player, item, opts)
			return opts
		end,
		remove_left_wield_item = function() end,
		get_left_wield_first_person = function(player)
			return true
		end,
		register_equip_sound = function() end,
		register_item_action = function() end,
		register_blocking_predicate = function() end,
		register_on_state_change = function() end,
	}
	x_player_armor.compat_x_player_api.init()

	local p = create_mock_player("e2_world_player")
	local opts = x_player_armor.compat_x_player_api.attach_shield(p, "x_player_armor:shield_steel")
	assert(opts.first_person == true, "opts.first_person must be true when x_player_api.enable_left_wield_first_person is enabled")
	assert(opts.visual == "wielditem", "opts.visual must be 'wielditem'")
	assert(x_player_armor.compat_x_player_api.get_shield_first_person(p) == true, "get_shield_first_person must return true")

	-- Clean up
	_G.x_player_api = nil
	x_player_armor.compat_x_player_api.init()
end)

test("Shield Off-Hand Update (update_shield & update_left_wield_item)", function()
	local updated_record = nil
	_G.x_player_api = {
		update_left_wield_item = function(player, item, opts)
			updated_record = {player = player, item = item, opts = opts}
			return {id = "shield_obj"}
		end,
		attach_left_wield_item = function()
			return {id = "shield_obj"}
		end,
		get_left_wield_first_person = function() return true end,
		register_equip_sound = function() end,
		register_item_action = function() end,
		register_blocking_predicate = function() end,
		register_on_state_change = function() end,
	}
	x_player_armor.compat_x_player_api.init()

	local p = create_mock_player("shield_updater")
	local ret = x_player_armor.update_shield(p, "x_player_armor:shield_diamond")
	assert(ret ~= nil and ret.id == "shield_obj", "update_shield must delegate to update_left_wield_item")
	assert(updated_record ~= nil, "update_left_wield_item must be invoked")
	assert(updated_record.item == "x_player_armor:shield_diamond", "Item name must match")

	-- Clean up
	_G.x_player_api = nil
	x_player_armor.compat_x_player_api.init()
end)

test("Event-Driven Slot Syncing & Armor Group Modifiers (register_on_wield_change)", function()
	local wield_callback = nil
	_G.x_player_api = {
		register_equip_sound = function() end,
		register_item_action = function() end,
		register_blocking_predicate = function() end,
		register_on_state_change = function() end,
		register_on_wield_change = function(cb)
			wield_callback = cb
		end,
	}
	x_player_armor.compat_x_player_api.init()
	assert(wield_callback ~= nil, "x_player_armor must register on_wield_change with x_player_api")

	local player = create_mock_player("event_sync_hero")
	x_player_armor.inventory.init_player_inventory(player)
	player.wielded_item = ItemStack("default:sword_steel")
	player:set_wield_index(1)

	local groups_updated = false
	local orig_set_armor_groups = player.set_armor_groups
	player.set_armor_groups = function(self, groups)
		groups_updated = true
		self.armor_groups = groups
	end

	-- Fire event callback as x_player_api would on slot change
	player:set_wield_index(2)
	player.wielded_item = ItemStack("x_player_armor:shield_wood")
	wield_callback(player, "x_player_armor:shield_wood", "default:sword_steel", player.wielded_item, 2, 1)

	assert(x_player_armor.ui.player_wield["event_sync_hero"].index == 2, "Wield slot tracking must update immediately")
	assert(x_player_armor.ui.player_wield["event_sync_hero"].item == "x_player_armor:shield_wood", "Tracked item must update immediately")
	assert(groups_updated == true, "Armor groups and modifiers must re-evaluate immediately without globalstep polling")

	-- Clean up
	player.set_armor_groups = orig_set_armor_groups
	_G.x_player_api = nil
	x_player_armor.compat_x_player_api.init()
end)

test("Shield Blocking Predicate Registration via x_player_api Subsystem", function()
	local registered_predicate = nil
	_G.x_player_api = {
		register_equip_sound = function() end,
		register_item_action = function() end,
		register_blocking_predicate = function(pred)
			registered_predicate = pred
		end,
		register_on_state_change = function() end,
	}
	x_player_armor.compat_x_player_api.init()
	assert(registered_predicate ~= nil, "x_player_armor must register a blocking predicate with x_player_api")

	local player = create_mock_player("shield_blocker")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)

	-- 1. Initially no shield is equipped -> predicate returns false
	local can_block_empty = registered_predicate(player, "default:sword_steel", {is_shield = false})
	assert(can_block_empty == false, "Blocking predicate must return false when no shield is equipped")

	-- 2. Equip shield into Slot 5 (armor inventory)
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_wood"))
	local can_block_equipped = registered_predicate(player, "default:sword_steel", {is_shield = false})
	assert(can_block_equipped == true, "Blocking predicate must return true when shield is equipped in armor slot 5")

	-- 3. Also works when holding empty hand or tools
	local can_block_pick = registered_predicate(player, "default:pick_steel", {is_shield = false})
	assert(can_block_pick == true, "Blocking predicate must return true regardless of main hand wielded item")

	-- 4. Unequip shield -> predicate returns false
	inv:set_stack("armor", 5, ItemStack(""))
	local can_block_unequipped = registered_predicate(player, "default:sword_steel", {is_shield = false})
	assert(can_block_unequipped == false, "Blocking predicate must return false after unequip")

	-- Clean up
	_G.x_player_api = nil
	x_player_armor.compat_x_player_api.init()
end)

test("Player Disconnect Cleanup and Reconnect Visuals Healing", function()
	local player = create_mock_player("reconnect_hero")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)

	-- Equip diamond helmet and chestplate
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_diamond"))

	local mock_glb = {
		is_valid = function() return true end,
		get_pos = function() return {x = 0, y = 10, z = 0} end,
	}
	local mock_b3d = {
		is_valid = function() return true end,
		get_pos = function() return {x = 0, y = 10, z = 0} end,
	}

	_G.x_player_api = {
		get_visual_proxies = function(p)
			return {glb = mock_glb, b3d = mock_b3d}
		end,
		get_modern_observers = function() return {} end,
		get_legacy_observers = function() return {} end,
	}

	-- 1. Initial spawn attaches to proxies
	x_player_armor.visuals.update_player_visuals(player)
	local ents = x_player_armor.visuals.player_entities["reconnect_hero"]
	assert(ents ~= nil, "player_entities entry must exist")
	assert(ents.head ~= nil and #ents.head == 2, "2 head pieces expected across dual proxies")
	assert(ents.torso ~= nil and #ents.torso == 6, "6 torso pieces expected across dual proxies")

	local first_head = ents.head[1]
	assert(first_head:is_valid() == true, "Head entity must be valid initially")
	assert(first_head:get_attach() ~= nil, "Head entity must be attached")

	-- 2. Player logs out: core.callbacks.on_leaveplayer triggers visuals.clear_all
	for _, cb in ipairs(core.callbacks.on_leaveplayer) do
		cb(player)
	end

	assert(x_player_armor.visuals.player_entities["reconnect_hero"] == nil, "player_entities entry must be nil after logout")
	assert(first_head:is_valid() == false, "Armor entity must be removed on player disconnect")
	assert(first_head.attachment == nil, "Armor entity must be detached on player disconnect")

	-- 3. Player logs back in with NEW proxies
	local new_glb = {
		is_valid = function() return true end,
		get_pos = function() return {x = 0, y = 10, z = 0} end,
	}
	local new_b3d = {
		is_valid = function() return true end,
		get_pos = function() return {x = 0, y = 10, z = 0} end,
	}
	_G.x_player_api.get_visual_proxies = function(p)
		return {glb = new_glb, b3d = new_b3d}
	end

	x_player_armor.visuals.update_player_visuals(player)
	local new_ents = x_player_armor.visuals.player_entities["reconnect_hero"]
	assert(new_ents ~= nil, "New player_entities entry must exist after reconnect")
	assert(new_ents.head ~= nil and #new_ents.head == 2, "New head entities must be spawned")
	assert(new_ents.head[1]:get_attach() == new_glb or new_ents.head[1]:get_attach() == new_b3d, "New entity must attach to new proxy")

	-- 4. Self-healing check: if player_entities contains an entity attached to stale/nil parent
	local stale_obj = new_ents.head[1]
	stale_obj.attachment = nil -- simulate sudden engine detachment or stale proxy
	x_player_armor.visuals.update_player_visuals(player)
	-- Stale object must have been cleaned up and replaced
	assert(stale_obj:is_valid() == false, "Stale detached entity must be removed during reconciliation")
	local healed_ents = x_player_armor.visuals.player_entities["reconnect_hero"]
	assert(healed_ents.head[1]:is_valid() == true, "Fresh entity must be attached in place of stale one")
	assert(healed_ents.head[1]:get_attach() ~= nil, "Fresh entity must be properly attached")

	-- 5. Orphan purge: cleanup_orphaned_visuals removes unattached entities in player radius
	local orig_get_objs = core.get_objects_inside_radius
	local orphan = core.add_entity({x = 0, y = 0, z = 0}, "x_player_armor:visual")
	core.get_objects_inside_radius = function(pos, radius)
		return {orphan}
	end
	local cleaned = x_player_armor.visuals.cleanup_orphaned_visuals()
	assert(cleaned >= 1, "cleanup_orphaned_visuals must remove unattached entity")
	assert(orphan:is_valid() == false, "Unattached orphan must be removed by cleanup_orphaned_visuals")
	core.get_objects_inside_radius = orig_get_objs

	-- Cleanup
	x_player_armor.visuals.clear_all("reconnect_hero")
	_G.x_player_api = nil
end)

test("1st-Person Shield Blocking HUD Indicator Lifecycle, Sizing & Z-Index", function()
	local player = create_mock_player("hud_hero")
	local inv = core.create_detached_inventory("hud_hero_armor", {}, "hud_hero")
	local orig_get_inv = player.get_inventory
	player.get_inventory = function() return inv end

	-- 1. Without shield equipped: show returns nil and does not add HUD
	local no_shield_id = x_player_armor.shield_hud.show(player)
	assert(no_shield_id == nil, "show() without equipped shield must return nil")
	assert(x_player_armor.get_shield_block_hud(player) == nil, "No HUD element should exist without shield")

	-- 2. Equip wood shield in slot 5 of detached armor inventory
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_wood 1 0"))
	local hud_id = x_player_armor.shield_hud.show(player)
	assert(hud_id ~= nil, "show() with equipped shield must return valid HUD ID")
	assert(x_player_armor.get_shield_block_hud(player) == hud_id, "get_shield_block_hud must return active HUD ID")

	local elem = player:hud_get(hud_id)
	assert(elem ~= nil, "HUD element must exist in player HUD table")
	assert(elem.hud_elem_type == "image", "HUD element type must be 'image'")
	assert(elem.z_index == -1, "HUD element z_index must be -1 (over vignettes, behind UI)")
	assert(elem.text:find("%[combine:524x524"), "Texture must be 2.5D extruded composite texture")
	assert(elem.text:find("0,12=%(x_player_armor_inv_shield_wood%.png"), "Front face must be wrapped in parentheses and properly resized")
	assert(elem.scale.x == 1.649 and elem.scale.y == 1.649, "Scale on 1080p must be 1.649 (45% screen width on 524x524 canvas)")
	assert(elem.position.x == 0 and elem.position.y == 1, "Position must be bottom-left (0, 1)")
	assert(elem.alignment.x == 1 and elem.alignment.y == -1, "Alignment must grow rightward and upward (1, -1)")
	assert(elem.offset.x == 48 and elem.offset.y == 378, "Offset must provide 48px natural left spacing and submerge bottom tip (y=378)")

	-- 3. Verify texture memoization
	assert(x_player_armor.shield_hud.texture_cache["x_player_armor:shield_wood"]:find("%[combine:524x524"), "Extruded texture string must be memoized in cache")

	-- 4. Test dynamic resolution scaling on 720p
	local orig_win_fn = core.get_player_window_information
	core.get_player_window_information = function()
		return {size = {x = 1280, y = 720}}
	end
	local updated_id = x_player_armor.shield_hud.show(player)
	assert(updated_id == hud_id, "Re-showing active HUD must update in-place without leaking IDs")
	local updated_elem = player:hud_get(hud_id)
	assert(updated_elem.scale.x == 1.099 and updated_elem.scale.y == 1.099, "Scale on 720p must be 1.099 (45% screen width)")
	assert(updated_elem.offset.x == 32 and updated_elem.offset.y == 252, "Offset on 720p must provide 32px left spacing and submerge bottom tip (y=252)")

	-- 4b. Test fallback when window info is nil
	core.get_player_window_information = function()
		return nil
	end
	x_player_armor.shield_hud.show(player)
	local fallback_elem = player:hud_get(hud_id)
	assert(fallback_elem.scale.x == 1.649 and fallback_elem.scale.y == 1.649, "Fallback scale must be 1.649")
	assert(fallback_elem.offset.x == 48 and fallback_elem.offset.y == 378, "Fallback offset must be {x=48, y=378}")
	core.get_player_window_information = orig_win_fn

	-- 5. Test hide()
	x_player_armor.shield_hud.hide(player)
	assert(player:hud_get(hud_id) == nil, "HUD element must be removed after hide()")
	assert(x_player_armor.get_shield_block_hud(player) == nil, "get_shield_block_hud must be nil after hide()")

	-- 6. Test death lifecycle callback (on_dieplayer hides HUD)
	x_player_armor.shield_hud.show(player)
	assert(x_player_armor.get_shield_block_hud(player) ~= nil, "HUD must be active before death")
	for _, fn in ipairs(core.callbacks.on_dieplayer) do
		fn(player)
	end
	assert(x_player_armor.get_shield_block_hud(player) == nil, "HUD must be hidden on player death")

	-- 7. Test leave lifecycle callback (on_leaveplayer purges tracking)
	x_player_armor.shield_hud.active_huds["hud_hero"] = 999
	for _, fn in ipairs(core.callbacks.on_leaveplayer) do
		fn(player)
	end
	assert(x_player_armor.shield_hud.active_huds["hud_hero"] == nil, "HUD tracking must be cleared on player leave")

	-- 8b. Auxiliary slot 6 shield resolution
	inv:set_stack("armor", 5, ItemStack(""))
	inv:set_stack("armor", 6, ItemStack("x_player_armor:shield_diamond 1 0"))
	local aux_id = x_player_armor.shield_hud.show(player)
	assert(aux_id ~= nil, "Auxiliary slot 6 shield must show shield HUD")
	assert(player:hud_get(aux_id).text:find("x_player_armor_inv_shield_diamond%.png"), "Texture must be diamond shield")
	x_player_armor.shield_hud.hide(player)

	-- 8c. Main hand wielded shield without armor slot must NOT show shield HUD
	inv:set_stack("armor", 6, ItemStack(""))
	player:set_wielded_item(ItemStack("x_player_armor:shield_wood 1 0"))
	local wield_id = x_player_armor.shield_hud.show(player)
	assert(wield_id == nil, "Main hand wielded shield without armor slot must NOT show shield HUD")
	player:set_wielded_item(ItemStack(""))

	-- 8d. Left hand wield item fallback resolution (x_player_api)
	_G.x_player_api = {
		get_left_wield_item = function(_p)
			return "x_player_armor:shield_enhanced_cactus"
		end,
	}
	local left_id = x_player_armor.shield_hud.show(player)
	assert(left_id ~= nil, "Left hand wielded shield via x_player_api must show shield HUD")
	assert(player:hud_get(left_id).text:find("x_player_armor_inv_shield_enhanced_cactus%.png"), "Texture must be enhanced cactus shield")
	x_player_armor.shield_hud.hide(player)
	_G.x_player_api = nil

	-- Restore original player methods
	player.get_inventory = orig_get_inv
end)

test("1st-Person Shield Blocking HUD x_player_api State Transition Listener", function()
	local player = create_mock_player("state_hero")
	local inv = core.create_detached_inventory("state_hero_armor", {}, "state_hero")
	local orig_get_inv = player.get_inventory
	player.get_inventory = function() return inv end
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel 1 0"))

	-- Mock x_player_api with state change listener
	local state_listener = nil
	_G.x_player_api = {
		register_equip_sound = function() end,
		register_item_action = function() end,
		register_blocking_predicate = function() end,
		register_on_state_change = function(fn)
			state_listener = fn
		end,
	}

	-- Initialize compat hooks
	x_player_armor.compat_x_player_api.init()
	assert(type(state_listener) == "function", "x_api.register_on_state_change must receive listener callback")

	-- Simulate entering block stance
	state_listener(player, {action = "block", blocking = true}, "stand", "idle")
	local hud_id = x_player_armor.get_shield_block_hud(player)
	assert(hud_id ~= nil, "Entering 'block' action must show shield HUD")
	local elem = player:hud_get(hud_id)
	assert(elem.z_index == -1, "HUD element z_index must be -1")
	assert(elem.text:find("x_player_armor_inv_shield_steel%.png"), "Texture must be steel shield")

	-- Simulate taking combat damage while blocking (out_state.blocking remains true while action is 'hurt')
	state_listener(player, {action = "hurt", blocking = true}, "stand", "block")
	assert(x_player_armor.get_shield_block_hud(player) == hud_id, "Shield HUD must persist when taking damage while blocking")

	-- Simulate leaving block stance
	state_listener(player, {action = "idle", blocking = false}, "stand", "hurt")
	assert(x_player_armor.get_shield_block_hud(player) == nil, "Leaving 'block' action must hide shield HUD")

	-- Cleanup
	player.get_inventory = orig_get_inv
	_G.x_player_api = nil
end)

test("1st-Person Shield Blocking HUD Debounce Delay & Right-Click Tap Suppression", function()
	local player = create_mock_player("debounce_hero")
	local inv = core.create_detached_inventory("debounce_hero_armor", {}, "debounce_hero")
	local orig_get_inv = player.get_inventory
	player.get_inventory = function() return inv end
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel 1 0"))

	local state_listener = nil
	_G.x_player_api = {
		register_equip_sound = function() end,
		register_item_action = function() end,
		register_blocking_predicate = function() end,
		register_on_state_change = function(fn)
			state_listener = fn
		end,
	}
	x_player_armor.compat_x_player_api.init()

	-- Mock controllable core.after queue
	local orig_after = core.after
	local scheduled_timers = {}
	core.after = function(delay, fn, ...)
		local args = {...}
		local job = {
			delay = delay,
			cancelled = false,
			cancel = function(self) self.cancelled = true end,
			run = function(self)
				if not self.cancelled then
					local unpack_fn = unpack or table.unpack
					fn(unpack_fn(args))
				end
			end,
		}
		table.insert(scheduled_timers, job)
		return job
	end

	-- 1. Simulate right-click tap to place block / interact with node (released within debounce window)
	state_listener(player, {action = "block", blocking = true}, "stand", "idle")
	assert(#scheduled_timers == 1, "Debounce timer must be scheduled on RMB press")
	assert(scheduled_timers[1].delay == 0.35, "Debounce delay must default to 0.35s")
	assert(x_player_armor.get_shield_block_hud(player) == nil, "HUD must NOT show immediately on press (zero flash)")

	-- Release RMB before debounce expires (e.g. 50-100ms later)
	state_listener(player, {action = "idle", blocking = false}, "stand", "block")
	assert(scheduled_timers[1].cancelled == true, "Pending timer must be cancelled on early release")

	-- Time elapses and timer fires
	scheduled_timers[1]:run()
	assert(x_player_armor.get_shield_block_hud(player) == nil, "Cancelled timer must NOT display shield HUD (tap suppressed)")

	-- 2. Simulate holding RMB for intentional combat block (>350ms)
	scheduled_timers = {}
	state_listener(player, {action = "block", blocking = true}, "stand", "idle")
	assert(#scheduled_timers == 1, "Timer must be scheduled for intentional block")
	assert(x_player_armor.get_shield_block_hud(player) == nil, "HUD still hidden during debounce window")

	-- Timer fires after 350ms delay while player is still holding block
	scheduled_timers[1]:run()
	local hud_id = x_player_armor.get_shield_block_hud(player)
	assert(hud_id ~= nil, "HUD must appear once debounce delay expires")
	assert(player:hud_get(hud_id) ~= nil, "HUD element must exist in player HUD table")

	-- Release block stance
	state_listener(player, {action = "idle", blocking = false}, "stand", "block")
	assert(x_player_armor.get_shield_block_hud(player) == nil, "HUD must hide on release")

	-- 3. Immediate parameter override: show(player, true) bypasses debounce delay
	scheduled_timers = {}
	local immediate_id = x_player_armor.shield_hud.show(player, true)
	assert(immediate_id ~= nil, "Immediate show must return valid HUD ID synchronously")
	assert(#scheduled_timers == 0, "Immediate show must NOT schedule a core.after timer")
	assert(x_player_armor.get_shield_block_hud(player) == immediate_id)
	x_player_armor.shield_hud.hide(player)

	-- 4. Disconnect cleanup during pending debounce timer
	scheduled_timers = {}
	state_listener(player, {action = "block", blocking = true}, "stand", "idle")
	assert(#scheduled_timers == 1)
	for _, fn in ipairs(core.callbacks.on_leaveplayer) do
		fn(player)
	end
	assert(scheduled_timers[1].cancelled == true, "Pending timer must be cancelled on player leave")
	assert(x_player_armor.shield_hud.pending_timers["debounce_hero"] == nil, "Pending timers tracking must be purged")

	-- 5. Configurable disable toggle: constants.SHIELD_HUD_ENABLE = false silences HUD completely
	x_player_armor.constants.SHIELD_HUD_ENABLE = false
	assert(x_player_armor.shield_hud.show(player, true) == nil, "show must return nil when SHIELD_HUD_ENABLE is false")
	x_player_armor.constants.SHIELD_HUD_ENABLE = true

	-- Restore core.after and cleanup
	core.after = orig_after
	player.get_inventory = orig_get_inv
	_G.x_player_api = nil
end)

test("Shield Blocking State Detection (x_player_armor.is_blocking)", function()
	local player = create_mock_player("block_state_hero")
	local inv = core.create_detached_inventory("block_state_hero_armor", {}, "block_state_hero")
	local orig_get_inv = player.get_inventory
	player.get_inventory = function() return inv end

	-- 1. Without shield: is_blocking must return false
	local is_blk, stack, slot, mat = x_player_armor.is_blocking(player)
	assert(is_blk == false, "Must return false when no shield equipped")
	assert(stack == nil and slot == nil and mat == nil)

	-- 2. Shield in slot 5, but controls RMB is false: is_blocking must return false
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel 1 0"))
	player.controls = {RMB = false, place = false}
	is_blk, stack, slot, mat = x_player_armor.is_blocking(player)
	assert(is_blk == false, "Must return false when RMB is not held")

	-- 3. Shield in slot 5, controls RMB is true (standalone fallback): is_blocking returns true
	player.controls = {RMB = true}
	is_blk, stack, slot, mat = x_player_armor.is_blocking(player)
	assert(is_blk == true, "Must return true when RMB is held with shield equipped")
	assert(slot == 5, "Slot must be 5")
	assert(mat == "steel", "Material must be steel")
	assert(stack:get_name() == "x_player_armor:shield_steel", "Stack name must match")

	-- 4. Shield held in right hand (hotbar) without armor inventory slot: must NOT block
	inv:set_stack("armor", 5, ItemStack(""))
	inv:set_stack("armor", 6, ItemStack(""))
	player.wielded_item = ItemStack("x_player_armor:shield_diamond 1 0")
	player.controls = {RMB = true}
	is_blk, stack, slot, mat = x_player_armor.is_blocking(player)
	assert(is_blk == false, "Shield held in right hand hotbar must NOT count as blocking")
	assert(stack == nil, "Stack must be nil when not in armor inventory")

	-- 5. x_player_api high-level semantic state integration and left-hand wield tracking
	player.wielded_item = ItemStack("")
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_nether 1 0"))
	player.controls = {RMB = false}
	_G.x_player_api = {
		is_present = function() return true end,
		get_player_state = function(_p)
			return {blocking = true, action = "block"}
		end,
		get_left_wield_item = function(_p)
			return "x_player_armor:shield_nether"
		end,
		register_equip_sound = function() end,
		register_item_action = function() end,
		register_blocking_predicate = function() end,
		register_on_state_change = function() end,
	}
	x_player_armor.compat_x_player_api.init()
	is_blk, stack, slot, mat = x_player_armor.is_blocking(player)
	assert(is_blk == true, "Must return true when x_player_api reports blocking with left hand shield")
	assert(slot == 5, "Slot must be 5")
	assert(mat == "nether", "Material must be nether")

	-- 6. When x_player_api reports non-shield in left hand (e.g. torch), blocking fails even if slot 5 has shield
	_G.x_player_api.get_left_wield_item = function(_p)
		return "default:torch"
	end
	is_blk, stack, slot, mat = x_player_armor.is_blocking(player)
	assert(is_blk == false, "Must not block when left hand wields non-shield item")
	assert(stack == nil, "Stack must be nil when left hand has non-shield")

	-- 7. When player wields a bow or two-handed weapon, blocking must return false
	_G.x_player_api.get_left_wield_item = function(_p)
		return "x_player_armor:shield_nether"
	end
	core.registered_items["x_bows:bow_wood"] = {
		groups = {bow = 1}
	}
	player.wielded_item = ItemStack("x_bows:bow_wood")
	is_blk, stack, slot, mat = x_player_armor.is_blocking(player)
	assert(is_blk == false, "Must not block when wielding bow (two-handed weapon)")

	-- Cleanup
	player.wielded_item = ItemStack("")
	_G.x_player_api = nil
	x_player_armor.compat_x_player_api.init()
	player.get_inventory = orig_get_inv
end)

test("Shield Blocking Capability Evaluation (x_player_armor.can_block & x_player_api delegation)", function()
	local player = create_mock_player("can_block_hero")
	local inv = core.create_detached_inventory("can_block_hero_armor", {}, "can_block_hero")
	local orig_get_inv = player.get_inventory
	player.get_inventory = function() return inv end

	-- 1. Without shield: can_block must return false
	assert(x_player_armor.can_block(player) == false, "Must return false when no shield equipped")
	assert(x_player_armor.combat.can_block(player) == false, "combat.can_block must match")

	-- 2. Shield equipped in Slot 5: can_block returns true
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_wood"))
	assert(x_player_armor.can_block(player) == true, "Must return true with shield equipped")

	-- 3. Holding bow: can_block returns false
	core.registered_items["default:bow"] = {groups = {bow = 1}}
	player.wielded_item = ItemStack("default:bow")
	assert(x_player_armor.can_block(player) == false, "Must return false when wielding bow")

	-- 4. Holding two-handed weapon: can_block returns false
	core.registered_items["default:greatsword"] = {groups = {two_handed = 1}}
	player.wielded_item = ItemStack("default:greatsword")
	assert(x_player_armor.can_block(player) == false, "Must return false when wielding two-handed weapon")

	-- 5. Delegation to x_player_api.evaluate_can_block when available
	player.wielded_item = ItemStack("")
	local evaluate_called = false
	_G.x_player_api = {
		is_present = function() return true end,
		evaluate_can_block = function(p)
			if p == player then
				evaluate_called = true
				return true
			end
			return false
		end,
		register_equip_sound = function() end,
		register_item_action = function() end,
		register_blocking_predicate = function() end,
		register_on_state_change = function() end,
	}
	x_player_armor.compat_x_player_api.init()
	assert(x_player_armor.can_block(player) == true, "Must return true via x_player_api.evaluate_can_block")
	assert(evaluate_called == true, "x_player_api.evaluate_can_block must be invoked")

	-- Clean up
	_G.x_player_api = nil
	x_player_armor.compat_x_player_api.init()
	player.get_inventory = orig_get_inv
end)

test("Frontal Blocking Cone Validation (x_player_armor.is_facing_attack)", function()
	local player = create_mock_player("cone_hero")
	player.look_dir = {x = 0, y = 0, z = 1} -- Facing North (+Z)

	-- 1. Direct frontal attack: attacker is at North firing South (attack_dir = {0, 0, -1})
	local front_attack = {x = 0, y = 0, z = -1}
	assert(x_player_armor.is_facing_attack(player, front_attack, 130) == true, "Direct frontal attack must be blocked")

	-- 2. 45-degree angle attack from North-West
	local rad45 = math.rad(45)
	local angle45_attack = {x = math.sin(rad45), y = 0, z = -math.cos(rad45)}
	assert(x_player_armor.is_facing_attack(player, angle45_attack, 130) == true, "45-degree frontal attack must be within 130-deg cone")

	-- 3. Rear attack: attacker is at South attacking North (attack_dir = {0, 0, 1})
	local rear_attack = {x = 0, y = 0, z = 1}
	assert(x_player_armor.is_facing_attack(player, rear_attack, 130) == false, "Rear attack must bypass frontal shield cone")

	-- 4. Flank attack from 90 degrees East (attack_dir = {-1, 0, 0})
	local flank_attack = {x = -1, y = 0, z = 0}
	assert(x_player_armor.is_facing_attack(player, flank_attack, 130) == false, "90-degree flank attack must bypass 130-deg cone")
end)

test("Active Shield Blocking Damage Mitigation & Recoil Impulse", function()
	local player = create_mock_player("mitigation_hero")
	local inv = core.create_detached_inventory("mitigation_hero_armor", {}, "mitigation_hero")
	local orig_get_inv = player.get_inventory
	player.get_inventory = function() return inv end

	player.look_dir = {x = 0, y = 0, z = 1}
	player.controls = {RMB = true}

	-- Equip Steel Shield (15% reduction) in slot 5
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel 1 0"))

	-- Set cached punch direction from front: attacker attacked towards -Z (attack_dir = {0, 0, -1})
	x_player_armor.combat.last_punch_dirs["mitigation_hero"] = {x = 0, y = 0, z = -1}

	-- Trigger hpchange hook with 20 damage (hp_change = -20)
	local hp_callbacks = core.callbacks.on_player_hpchange
	local hp_result = -20
	for _, cb in ipairs(hp_callbacks) do
		hp_result = cb(player, hp_result, {type = "punch"}) or hp_result
	end

	-- 15% of 20 = 3 damage blocked; new hp_change should be -17
	assert(hp_result == -17, "Steel shield must mitigate 15% of 20 damage (result -17, was " .. tostring(hp_result) .. ")")

	-- Verify recoil impulse was applied to player
	assert(player.last_added_velocity ~= nil, "Player must receive recoil velocity on block")
	assert(player.last_added_velocity.z < 0, "Recoil must push player back along attack vector")

	-- Test Diamond Shield (20% reduction)
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_diamond 1 0"))
	x_player_armor.combat.last_punch_dirs["mitigation_hero"] = {x = 0, y = 0, z = -1}
	hp_result = -20
	for _, cb in ipairs(hp_callbacks) do
		hp_result = cb(player, hp_result, {type = "punch"}) or hp_result
	end
	-- 20% of 20 = 4 damage blocked; new hp_change should be -16
	assert(hp_result == -16, "Diamond shield must mitigate 20% of 20 damage (result -16, was " .. tostring(hp_result) .. ")")

	-- Test Rear Attack (bypasses block, 0% mitigation)
	x_player_armor.combat.last_punch_dirs["mitigation_hero"] = {x = 0, y = 0, z = 1}
	hp_result = -20
	for _, cb in ipairs(hp_callbacks) do
		hp_result = cb(player, hp_result, {type = "punch"}) or hp_result
	end
	assert(hp_result == -20, "Rear attack must not be mitigated (result -20)")

	-- Cleanup
	player.get_inventory = orig_get_inv
end)

test("Natural Projectile Deflection Physics & Orientation (x_player_armor.try_deflect_projectile)", function()
	local player = create_mock_player("deflect_hero")
	local inv = core.create_detached_inventory("deflect_hero_armor", {}, "deflect_hero")
	local orig_get_inv = player.get_inventory
	player.get_inventory = function() return inv end

	player.look_dir = {x = 0, y = 0, z = 1}
	player.controls = {RMB = true}

	-- Equip Steel Shield (restitution = 0.50) in slot 5
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel 1 0"))

	-- Mock Projectile Entity
	local proj_vel = {x = 0, y = -1, z = -20}
	local proj_acc = {x = 0, y = 0, z = 0}
	local proj_rot = {x = 0, y = 0, z = 0}
	local proj_pos = {x = 0, y = 10, z = 2}
	local mock_proj = {
		valid = true,
		is_valid = function(self) return self.valid end,
		get_velocity = function(self) return proj_vel end,
		set_velocity = function(self, v) proj_vel = v end,
		set_acceleration = function(self, a) proj_acc = a end,
		set_rotation = function(self, r) proj_rot = r end,
		get_pos = function(self) return proj_pos end,
		set_pos = function(self, p) proj_pos = p end,
	}

	-- Deflect frontal arrow flying South towards player
	local flight_dir = {x = 0, y = 0, z = -1}
	local hit_pos = {x = 0, y = 10, z = 0.5}
	local deflected, bounce_vel = x_player_armor.try_deflect_projectile(player, mock_proj, hit_pos, flight_dir)

	assert(deflected == true, "try_deflect_projectile must return true for frontal block")
	assert(type(bounce_vel) == "table", "bounce_vel must be returned")

	-- Tier 1 check: Verify projectile entity pos was moved to shield contact origin
	local expected_shield_pos = x_player_armor.get_shield_contact_pos(player)
	assert(math.abs(proj_pos.x - expected_shield_pos.x) < 0.001, "Projectile pos.x must match shield contact origin")
	assert(math.abs(proj_pos.y - expected_shield_pos.y) < 0.001, "Projectile pos.y must match shield contact origin")
	assert(math.abs(proj_pos.z - expected_shield_pos.z) < 0.001, "Projectile pos.z must match shield contact origin")

	-- Verify natural reflection: bounce vector must point back outwards (+Z) and have positive lift (+Y >= 1.5)
	assert(bounce_vel.z > 0, "Bounce velocity z component must reflect forward/away (+Z), was " .. tostring(bounce_vel.z))
	assert(bounce_vel.y >= 1.5, "Bounce velocity y component must have upward clearance (>= 1.5), was " .. tostring(bounce_vel.y))

	-- Verify projectile entity received updated physics
	assert(proj_vel.z == bounce_vel.z, "Projectile object velocity must be updated to bounce_vel")
	assert(proj_acc.y == -9.81, "Projectile acceleration must be set to gravity (-9.81)")

	-- Verify player received recoil velocity in direction of incoming arrow
	assert(player.last_added_velocity ~= nil, "Player must receive push-back recoil")
	assert(player.last_added_velocity.z <= -3.0, "Recoil must push back with noticeable horizontal speed (<= -3.0 m/s), was " .. tostring(player.last_added_velocity.z))
	assert(player.last_added_velocity.y >= 1.6, "Recoil must provide vertical lift (>= 1.6 m/s) to overcome ground friction, was " .. tostring(player.last_added_velocity.y))

	-- Verify shield durability wear was applied
	local updated_shield = inv:get_stack("armor", 5)
	assert(updated_shield:get_wear() > 0, "Equipped shield must take durability wear from deflecting arrow")

	-- Test Rear Projectile (must NOT be deflected)
	local rear_flight_dir = {x = 0, y = 0, z = 1}
	local rear_deflected = x_player_armor.try_deflect_projectile(player, mock_proj, hit_pos, rear_flight_dir)
	assert(rear_deflected == false, "Arrow hitting player in back must not be deflected")

	-- Cleanup
	player.get_inventory = orig_get_inv
end)

test("Tier 1: Shield Contact Surface Origin Math (get_shield_contact_pos)", function()
	local p = create_mock_player("origin_hero")
	p.pos = {x = 10, y = 5, z = 20}
	p.look_dir = {x = 0, y = 0, z = 1} -- Facing North (+Z)

	local s_pos = x_player_armor.get_shield_contact_pos(p)
	-- When facing North (+Z):
	-- Forward is +Z -> s_pos.z should be > 20.0 (offset by ~0.65m)
	assert(s_pos.z > 20.5 and s_pos.z < 20.8, "Shield pos.z must be ~0.65m forward")
	-- Left is -X -> s_pos.x should be < 10.0 (offset by ~-0.40m)
	assert(s_pos.x < 9.7 and s_pos.x > 9.4, "Shield pos.x must be ~0.40m to the left")
	-- Down from eye level (5 + 1.47 = 6.47) -> s_pos.y should be ~6.12m
	assert(s_pos.y < 6.3 and s_pos.y > 5.9, "Shield pos.y must be at chest/shield level")

	-- Turn East (+X)
	p.look_dir = {x = 1, y = 0, z = 0}
	local s_pos_east = x_player_armor.get_shield_contact_pos(p)
	-- Forward is +X -> s_pos_east.x should be > 10.0
	assert(s_pos_east.x > 10.5 and s_pos_east.x < 10.8, "Shield pos.x must be ~0.65m forward when facing East")
	-- Left of East is North (+Z) -> s_pos_east.z should be > 20.0
	assert(s_pos_east.z > 20.3 and s_pos_east.z < 20.6, "Shield pos.z must be ~0.40m to the left when facing East")
end)

test("Tier 2: Asymmetric Guard Cone Bias (Off-Hand Coverage, Right Flank Vulnerability & Shield Aiming)", function()
	local player = create_mock_player("bias_hero")
	player.look_dir = {x = 0, y = 0, z = 1} -- Facing North (+Z)

	-- 1. Shield center off-hand attack at -22 degrees (North-West):
	local rad22 = math.rad(22)
	local left_22_attack = {x = math.sin(rad22), y = 0, z = -math.cos(rad22)}
	assert(x_player_armor.is_facing_attack(player, left_22_attack, 52) == true,
		"22-deg left offhand attack directly hits shield center -> must block")

	-- 2. Left-hand shield coverage at -40 degrees (North-West):
	local rad40 = math.rad(40)
	local left_40_attack = {x = math.sin(rad40), y = 0, z = -math.cos(rad40)}
	assert(x_player_armor.is_facing_attack(player, left_40_attack, 52) == true,
		"40-deg left-side attack falls within offhand shield guard cone -> must block")

	-- 3. Center frontal attack (0 deg):
	assert(x_player_armor.is_facing_attack(player, {x = 0, y = 0, z = -1}, 52) == true,
		"Direct frontal attack (0 deg) hits right boundary of shield cone -> must block")

	-- 4. Right side of screen / view (+15 deg towards weapon side):
	-- Attacker fires from North-East (+15 deg from crosshair towards weapon arm)
	local rad15 = math.rad(15)
	local right_15_attack = {x = -math.sin(rad15), y = 0, z = -math.cos(rad15)}
	assert(x_player_armor.is_facing_attack(player, right_15_attack, 52) == false,
		"15-deg right-side attack must penetrate exposed weapon side under asymmetric bias")

	-- 5. Right side flank attacks (+30 deg, +55 deg) must penetrate:
	local rad30 = math.rad(30)
	local right_30_attack = {x = -math.sin(rad30), y = 0, z = -math.cos(rad30)}
	assert(x_player_armor.is_facing_attack(player, right_30_attack, 52) == false,
		"30-deg right-side attack must penetrate exposed weapon side")
	local rad55 = math.rad(55)
	local right_55_attack = {x = -math.sin(rad55), y = 0, z = -math.cos(rad55)}
	assert(x_player_armor.is_facing_attack(player, right_55_attack, 52) == false,
		"55-deg right-side flank attack must penetrate exposed weapon side")

	-- 6. Player aiming shield section at incoming right-side threat:
	-- Threat is at +15 deg from original orientation. Player turns right by 25 deg to aim the shield:
	local p_aim_rad = math.rad(25)
	player.look_dir = {x = math.sin(p_aim_rad), y = 0, z = math.cos(p_aim_rad)}
	assert(x_player_armor.is_facing_attack(player, right_15_attack, 52) == true,
		"Player aiming left shield section at right-side threat successfully deflects incoming attack")

	-- Reset player look_dir
	player.look_dir = {x = 0, y = 0, z = 1}

	-- 7. Rear attack (180 deg) must never block:
	assert(x_player_armor.is_facing_attack(player, {x = 0, y = 0, z = 1}, 52) == false,
		"Rear attack (180 deg) must never be blocked")

	-- 8. Vertical attack (straight down) must never pass horizontal guard cone:
	assert(x_player_armor.is_facing_attack(player, {x = 0, y = -1, z = 0}, 52) == false,
		"Vertical attack from straight above must never pass shield cone")

	-- 9. Spatial hit position checks in try_deflect_projectile:
	local inv = core.create_detached_inventory("bias_hero_armor", {}, "bias_hero")
	local orig_get_inv = player.get_inventory
	player.get_inventory = function() return inv end
	player.controls = {RMB = true}
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel 1 0"))

	local mock_proj = {
		valid = true,
		is_valid = function(self) return self.valid end,
		get_velocity = function(self) return {x = 0, y = 0, z = -15} end,
		set_velocity = function(self, v) end,
		set_acceleration = function(self, a) end,
		set_rotation = function(self, r) end,
		get_pos = function(self) return {x = 0, y = 10, z = 0.5} end,
		set_pos = function(self, p) end,
	}

	-- Front-left shield hit -> must deflect
	local front_left_hit = {x = -0.2, y = 10, z = 0.4}
	local ok1 = x_player_armor.try_deflect_projectile(player, mock_proj, front_left_hit, {x = 0, y = 0, z = -1})
	assert(ok1 == true, "Projectile hitting front-left shield position must be deflected")

	-- Rear hit on player back -> must penetrate (deflect = false)
	local rear_hit = {x = 0, y = 10, z = -0.3}
	local ok2 = x_player_armor.try_deflect_projectile(player, mock_proj, rear_hit, {x = 0, y = 0, z = -1})
	assert(ok2 == false, "Projectile physically striking player back must penetrate")

	-- Right flank hit on player weapon arm -> must penetrate (deflect = false)
	local right_flank_hit = {x = 0.3, y = 10, z = 0.2}
	local ok3 = x_player_armor.try_deflect_projectile(player, mock_proj, right_flank_hit, {x = 0, y = 0, z = -1})
	assert(ok3 == false, "Projectile physically striking player exposed right flank must penetrate")

	-- Cleanup
	player.get_inventory = orig_get_inv
end)

test("Option 1 & 2: Wield Change Events & Formspec Idle-Skipping", function()
	local player = create_mock_player("wield_ui_hero")

	-- Initially no armor UI is open
	assert(x_player_armor.has_any_open_armor_ui() == false,
		"Initially no player has armor UI open")
	assert(x_player_armor.is_armor_ui_open(player) == false,
		"Player armor UI must report closed")

	-- Opening standalone armor formspec sets open tracking
	x_player_armor.ui.show_armor_formspec(player)
	assert(x_player_armor.has_any_open_armor_ui() == true,
		"has_any_open_armor_ui must be true after show_armor_formspec")
	assert(x_player_armor.is_armor_ui_open(player) == true,
		"is_armor_ui_open must be true after show_armor_formspec")

	-- Closing formspec clears open tracking
	for _, fn in ipairs(core.callbacks.on_player_receive_fields) do
		fn(player, "x_player_armor:armor", {quit = "true"})
	end
	assert(x_player_armor.has_any_open_armor_ui() == false,
		"has_any_open_armor_ui must revert to false when formspec is quit")
	assert(x_player_armor.is_armor_ui_open(player) == false,
		"is_armor_ui_open must revert to false when formspec is quit")

	-- Test x_player_api.register_on_wield_change hook dispatching
	local x_api = x_player_armor.get_mod_api("x_player_api")
	if x_api and x_api.register_on_wield_change then
		local callback_received = false
		local reported_new_item = nil
		local reported_new_idx = nil
		x_api.register_on_wield_change(function(p, new_item, _prev_item, _stack, new_idx, _prev_idx)
			if p:get_player_name() == "wield_ui_hero" then
				callback_received = true
				reported_new_item = new_item
				reported_new_idx = new_idx
			end
		end)

		-- Trigger wield update via x_player_api controls
		local pstates = x_api.controls and x_api.controls.player_states
		if pstates and pstates["wield_ui_hero"] then
			player:set_wield_index(4)
			player.wielded_item = ItemStack("x_player_armor:shield_steel")
			x_api.update_player_controls(player, 0.1, 100.0)
			assert(callback_received == true, "x_player_api.register_on_wield_change callback must fire")
			assert(reported_new_item == "x_player_armor:shield_steel", "New item must be reported correctly")
			assert(reported_new_idx == 4, "New slot index must be reported correctly")
		end
	end
end)

test("Combat Armor HUD: Single Composite Element & Blueprint Paperdoll Layout", function()
	local defender = create_mock_player("hud_defender_1")
	x_player_armor.inventory.init_player_inventory(defender)
	local _, inv = x_player_armor.get_valid_player(defender)

	-- Equip steel helmet and diamond chestplate
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_steel"))
	inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_diamond"))
	x_player_armor.set_player_armor(defender)

	-- Trigger combat HUD
	local hud_id = x_player_armor.trigger_combat_hud(defender)
	assert(hud_id, "trigger_combat_hud must return a valid HUD ID")
	assert(x_player_armor.get_combat_hud_id(defender) == hud_id, "get_combat_hud_id must match returned ID")
	assert(defender.hud_counter == 1, "Exactly 1 single composite HUD element must be added (single element invariant)")

	local hud_elem = defender:hud_get(hud_id)
	assert(hud_elem, "HUD element must exist on player")
	assert(hud_elem.hud_elem_type == "image", "HUD element type must be image")
	assert(hud_elem.position.x == 1 and hud_elem.position.y == 1, "Default position must be bottom-right (1, 1)")
	assert(hud_elem.alignment.x == -1 and hud_elem.alignment.y == -1, "Default alignment must be bottom-right (-1, -1)")
	assert(hud_elem.z_index == 5, "Z-index must be 5")

	-- Composite texture contents
	local tex = hud_elem.text
	assert(tex:find("%[combine:96x128:"), "Texture must use 96x128 combine composite canvas")
	assert(tex:find("%[fill\\:96x128\\:#0d1117dd"), "Texture must use programmatic [fill dark glass plate (zero static PNG files)")
	assert(tex:find("%[fill\\:24x24\\:#161b22ee"), "Texture must use programmatic [fill slot wells")
	assert(tex:find("x_player_armor_inv_helmet_steel.png"), "Equipped helmet icon must be rendered")
	assert(tex:find("x_player_armor_inv_chestplate_diamond.png"), "Equipped chestplate icon must be rendered")
	assert(tex:find("x_player_armor_stand_shield.png"), "Empty shield slot must display blueprint silhouette")
	assert(tex:find("x_player_armor_stand_legs.png"), "Empty leggings slot must display blueprint silhouette")
	assert(tex:find("x_player_armor_stand_feet.png"), "Empty boots slot must display blueprint silhouette")

	-- Clean hide
	x_player_armor.hide_combat_hud(defender)
	assert(x_player_armor.get_combat_hud_id(defender) == nil, "get_combat_hud_id must return nil after hide")
	assert(defender:hud_get(hud_id) == nil, "HUD element must be removed from player on hide")
end)

test("Combat Armor HUD: Dirty-State Packet Suppression & In-Place Updates", function()
	local fighter = create_mock_player("hud_dirty_fighter")
	x_player_armor.inventory.init_player_inventory(fighter)
	local _, inv = x_player_armor.get_valid_player(fighter)

	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_steel"))
	x_player_armor.set_player_armor(fighter)

	local hud_id = x_player_armor.trigger_combat_hud(fighter)
	assert(hud_id, "Combat HUD must be created")

	-- Track hud_change calls
	local hud_change_calls = 0
	local orig_hud_change = fighter.hud_change
	fighter.hud_change = function(self, id, stat, val)
		hud_change_calls = hud_change_calls + 1
		orig_hud_change(self, id, stat, val)
	end

	-- Subsequent triggers without wear or equipment change must NOT send hud_change
	x_player_armor.trigger_combat_hud(fighter)
	x_player_armor.trigger_combat_hud(fighter)
	assert(hud_change_calls == 0, "Dirty-state optimization: 0 hud_change packets sent when visual state is identical")

	-- Wear is applied via combat.damage_item (uses = 10 applies ~10% wear, shrinking gauge from 20px to 18px)
	local stack = inv:get_stack("armor", 1)
	x_player_armor.combat.damage_item(fighter, 1, stack, 10)
	assert(hud_change_calls == 1, "hud_change must be called in-place exactly once when wear changes")

	-- Restore original method and clean up
	fighter.hud_change = orig_hud_change
	x_player_armor.hide_combat_hud(fighter)
end)

test("Combat Armor HUD: Incoming Damage Only (Outgoing Attacks Suppressed)", function()
	local defender = create_mock_player("hud_threat_victim")
	local attacker = create_mock_player("hud_threat_attacker")
	x_player_armor.inventory.init_player_inventory(defender)
	x_player_armor.inventory.init_player_inventory(attacker)

	-- 1. Attacker punches defender
	core.mock_players["hud_threat_victim"] = defender
	core.mock_players["hud_threat_attacker"] = attacker

	for _, fn in ipairs(core.callbacks.on_punchplayer) do
		fn(defender, attacker, 1.0, {}, {x = 0, y = 0, z = 1}, 4)
	end

	assert(x_player_armor.get_combat_hud_id(defender) ~= nil,
		"Defending player receiving punch must trigger combat HUD")
	assert(x_player_armor.get_combat_hud_id(attacker) == nil,
		"Attacking player dealing damage must NOT trigger combat HUD (incoming damage only invariant)")

	x_player_armor.hide_combat_hud(defender)

	-- 2. Negative HP change (incoming damage from environmental source or fall)
	for _, fn in ipairs(core.callbacks.on_player_hpchange) do
		fn(defender, -6, {type = "fall"})
	end
	assert(x_player_armor.get_combat_hud_id(defender) ~= nil,
		"Negative HP change must trigger combat HUD")

	x_player_armor.hide_combat_hud(defender)

	-- 3. Positive HP change (heal) must NOT trigger combat HUD
	for _, fn in ipairs(core.callbacks.on_player_hpchange) do
		fn(defender, 6, {type = "heal"})
	end
	assert(x_player_armor.get_combat_hud_id(defender) == nil,
		"Positive HP change (healing) must NOT trigger combat HUD")
end)

test("Combat Armor HUD: 5-Stage Transitional Durability Colors", function()
	local get_color = x_player_armor.combat_hud.get_durability_color

	-- Tier 5 (80% - 100%): Emerald Green
	assert(get_color(0) == "#2ea043", "0% wear (100% health) must be #2ea043 (Emerald Green)")
	assert(get_color(math.floor(65535 * 0.15)) == "#2ea043", "15% wear (85% health) must be #2ea043")

	-- Tier 4 (60% - 79%): Lime Green
	assert(get_color(math.floor(65535 * 0.30)) == "#7ee787", "30% wear (70% health) must be #7ee787 (Lime Green)")

	-- Tier 3 (40% - 59%): Amber Yellow
	assert(get_color(math.floor(65535 * 0.50)) == "#e3b341", "50% wear (50% health) must be #e3b341 (Amber Yellow)")

	-- Tier 2 (20% - 39%): Vivid Orange
	assert(get_color(math.floor(65535 * 0.70)) == "#f97316", "70% wear (30% health) must be #f97316 (Vivid Orange)")

	-- Tier 1 (0% - 19%): Crimson Red
	assert(get_color(math.floor(65535 * 0.90)) == "#f85149", "90% wear (10% health) must be #f85149 (Crimson Red)")
	assert(get_color(65535) == "#f85149", "100% wear (0% health) must be #f85149 (Crimson Red)")
end)

test("Combat Armor HUD: Throttled Timer Expiration, Timer Reset & Idle Skipping", function()
	x_player_armor.combat_hud.active_players = {}
	local player = create_mock_player("hud_timer_test")
	x_player_armor.inventory.init_player_inventory(player)

	-- Locate combat_hud globalstep
	local hud_step = nil
	for i = #core.callbacks.globalstep, 1, -1 do
		local fn = core.callbacks.globalstep[i]
		if fn then
			-- Test if this step interacts with combat_hud
			hud_step = fn
			break
		end
	end
	assert(hud_step, "Combat HUD globalstep must be registered")

	-- 1. Trigger HUD at t = 100
	local test_time = 100
	local orig_get_gametime = core.get_gametime
	core.get_gametime = function() return test_time end

	x_player_armor.trigger_combat_hud(player)
	local state = x_player_armor.combat_hud.active_players["hud_timer_test"]
	assert(state and state.expire_time == 105, "expire_time must be set to now + 5.0 (105)")

	-- 2. Subsequent combat hit at t = 103 resets timer to 108
	test_time = 103
	x_player_armor.trigger_combat_hud(player)
	assert(state.expire_time == 108, "Subsequent hit must reset expire_time to 108")

	-- 3. Step at t = 105 (before expiration) keeps HUD active
	test_time = 105
	hud_step(0.30)
	assert(x_player_armor.combat_hud.active_players["hud_timer_test"] ~= nil, "HUD must remain active before expire_time")

	-- 4. Step at t = 109 (after expiration) hides HUD
	test_time = 109
	hud_step(0.30)
	assert(x_player_armor.combat_hud.active_players["hud_timer_test"] == nil, "HUD must auto-hide after expire_time passes")
	assert(player:hud_get(state.hud_id) == nil, "HUD element must be removed from player")

	-- 5. Idle skipping: step when active_players is empty executes with zero overhead
	assert(next(x_player_armor.combat_hud.active_players) == nil, "active_players must be empty")
	hud_step(0.50) -- Must complete cleanly without errors

	core.get_gametime = orig_get_gametime
end)

test("Combat Armor HUD: Engine Lifecycle & Shutdown / Crash Resilience", function()
	local survivor = create_mock_player("hud_survivor")
	x_player_armor.inventory.init_player_inventory(survivor)

	-- 1. Player death removes HUD
	x_player_armor.trigger_combat_hud(survivor)
	assert(x_player_armor.get_combat_hud_id(survivor) ~= nil, "HUD must be active")
	for _, fn in ipairs(core.callbacks.on_dieplayer) do
		fn(survivor)
	end
	assert(x_player_armor.get_combat_hud_id(survivor) == nil, "Player death must immediately hide HUD")

	-- 2. Player respawn clears state
	x_player_armor.trigger_combat_hud(survivor)
	for _, fn in ipairs(core.callbacks.on_respawnplayer) do
		fn(survivor)
	end
	assert(x_player_armor.get_combat_hud_id(survivor) == nil, "Player respawn must immediately hide HUD")

	-- 3. Player disconnect cleans up tracking
	x_player_armor.trigger_combat_hud(survivor)
	assert(x_player_armor.combat_hud.active_players["hud_survivor"] ~= nil, "Tracking must be active")
	for _, fn in ipairs(core.callbacks.on_leaveplayer) do
		fn(survivor)
	end
	assert(x_player_armor.combat_hud.active_players["hud_survivor"] == nil, "Player disconnect must clean up tracking")

	-- 4. Server shutdown clears all active HUDs across players
	local p1 = create_mock_player("hud_shut_1")
	local p2 = create_mock_player("hud_shut_2")
	x_player_armor.inventory.init_player_inventory(p1)
	x_player_armor.inventory.init_player_inventory(p2)
	local id1 = x_player_armor.trigger_combat_hud(p1)
	local id2 = x_player_armor.trigger_combat_hud(p2)
	assert(id1 and id2, "Both players must have active combat HUDs")

	for _, fn in ipairs(core.callbacks.on_shutdown) do
		fn()
	end
	assert(next(x_player_armor.combat_hud.active_players) == nil, "Shutdown must completely purge active_players")
	assert(p1:hud_get(id1) == nil, "Shutdown must remove HUD element from player 1")
	assert(p2:hud_get(id2) == nil, "Shutdown must remove HUD element from player 2")

	-- 5. Safe handling when player object is invalid (e.g. disconnected or freed)
	local ghost = create_mock_player("hud_ghost")
	ghost.is_valid = function() return false end
	local ghost_id = x_player_armor.trigger_combat_hud(ghost)
	assert(ghost_id == nil, "Invalid player reference must safely abort without error")
end)

test("Combat Armor HUD: In-Combat Equipment Swap In-Place Update", function()
	local gladiator = create_mock_player("hud_gladiator")
	x_player_armor.inventory.init_player_inventory(gladiator)
	local _, inv = x_player_armor.get_valid_player(gladiator)

	-- Start combat with only wood helmet
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_wood"))
	x_player_armor.set_player_armor(gladiator)

	local hud_id = x_player_armor.trigger_combat_hud(gladiator)
	local initial_tex = gladiator:hud_get(hud_id).text
	assert(initial_tex:find("x_player_armor_inv_helmet_wood.png"), "Initial HUD must show wood helmet")
	assert(not initial_tex:find("x_player_armor_inv_chestplate_steel.png"), "Initial HUD must not show steel chestplate")

	-- Equip steel chestplate while in combat
	x_player_armor.equip(gladiator, ItemStack("x_player_armor:chestplate_steel"))

	local updated_tex = gladiator:hud_get(hud_id).text
	assert(updated_tex:find("x_player_armor_inv_chestplate_steel.png"), "In-combat equip must update composite HUD with steel chestplate")
	assert(gladiator.hud_counter == 1, "Single HUD element must be preserved across equipment changes (no element churn)")

	x_player_armor.hide_combat_hud(gladiator)
end)

test("Combat Armor HUD: Responsive Screen Scaling Across Viewports (1080p, 1440p, 4K)", function()
	local scaler = create_mock_player("hud_scaler")
	x_player_armor.inventory.init_player_inventory(scaler)

	local orig_win_info = core.get_player_window_information

	-- 1. Standard 1080p (1920x1080)
	core.get_player_window_information = function()
		return {size = {x = 1920, y = 1080}}
	end
	local s_1080, off_1080 = x_player_armor.combat_hud.get_proportional_geometry(scaler)
	assert(s_1080.x == 1.6, "1080p scale must be 1.6 baseline")
	assert(off_1080.x == -24 and off_1080.y == -24, "1080p offset must be -24, -24")

	-- 2. 1440p / 2K (2560x1440)
	core.get_player_window_information = function()
		return {size = {x = 2560, y = 1440}}
	end
	local s_1440, off_1440 = x_player_armor.combat_hud.get_proportional_geometry(scaler)
	assert(s_1440.x == 2.13, "1440p scale must scale up to 2.13 (1.6 * 1440/1080)")
	assert(off_1440.x == -32 and off_1440.y == -32, "1440p offset must scale up to -32, -32")

	-- 3. 4K / UHD (3840x2160)
	core.get_player_window_information = function()
		return {size = {x = 3840, y = 2160}}
	end
	local s_4k, off_4k = x_player_armor.combat_hud.get_proportional_geometry(scaler)
	assert(s_4k.x == 3.2, "4K scale must scale up to 3.2 (1.6 * 2160/1080)")
	assert(off_4k.x == -48 and off_4k.y == -48, "4K offset must scale up to -48, -48")

	core.get_player_window_information = orig_win_info
end)

test("Combat Armor HUD: Active Wielded Item Loadout & Durability in Slot 6", function()
	local warrior = create_mock_player("hud_wield_warrior")
	x_player_armor.inventory.init_player_inventory(warrior)

	-- 1. Bare hands: Slot 6 displays blueprint silhouette
	warrior.wielded_item = ItemStack("")
	local hud_id = x_player_armor.trigger_combat_hud(warrior)
	local bare_tex = warrior:hud_get(hud_id).text
	assert(bare_tex:find("x_player_armor_icon.png"), "Slot 6 must display blueprint silhouette when hands are bare")
	assert(bare_tex:find("x_player_armor_icon%.png%\\%^%[resize\\:16x16"), "Slot 6 blueprint silhouette must be resized to 16x16 to prevent slot overflow")

	-- 2. Wielding steel sword with wear: Slot 6 renders weapon and durability gauge
	local sword = ItemStack("default:sword_mithril")
	sword:add_wear(13107) -- 20% wear -> 80% health (Tier 5: #2ea043)
	warrior.wielded_item = sword

	-- Trigger wield change detection (reusable hook)
	x_player_armor.ui.check_wield_change(warrior)

	local armed_tex = warrior:hud_get(hud_id).text
	assert(armed_tex:find("default_tool_mithrilsword.png"), "Slot 6 must display active wielded sword texture")
	assert(armed_tex:find("%[fill\\:20x3\\:#161b22ff"), "Durability track must be rendered for damaged weapon")
	assert(armed_tex:find("#2ea043"), "Durability gauge must display 5-tier color for 80% health weapon")

	-- 3. Weapon wear changes in combat: HUD immediately updates in-place
	sword:add_wear(35000) -- Wear reaches ~73% -> health 27% (Tier 2: #f97316)
	warrior.wielded_item = sword
	x_player_armor.ui.check_wield_change(warrior)

	local damaged_tex = warrior:hud_get(hud_id).text
	assert(damaged_tex:find("#f97316"), "Durability gauge must transition to orange for heavily worn weapon")

	x_player_armor.hide_combat_hud(warrior)
end)

test("i3 Inventory Integration Shim: Armor Tab Auto-Enable", function()
	-- Simulate i3 loaded before x_player_armor
	local mock_i3 = {
		modules = {},
		set_fs = function() end,
	}
	_G.i3 = mock_i3

	-- Execute the compat shim logic
	local modpath = core.get_modpath("x_player_armor")
	dofile(modpath .. "/modules/compat/armor.lua")

	assert(mock_i3.modules.armor == true, "i3.modules.armor must be set to true immediately by x_player_armor shim")

	-- Clean up mock
	_G.i3 = nil
end)

test("Unified Inventory Integration: Button, Page, Layout & Open State", function()
	-- Disable sfinv as unified_inventory does
	sfinv.enabled = false

	-- 1. Setup mock unified_inventory
	local mock_ui
	mock_ui = {
		pages = {},
		buttons = {},
		current_page = {},
		standard_background = "bgcolor[#0000]background9[0,0;1,1;ui_formbg_9_sliced.png;true;16]",
		get_formspec = function(_player, _page)
			return "formspec_version[6]size[17,10]listcolors[#00000000;#00000000]tooltip[item_btn;Steel Sword]"
		end,
		style_full = {
			form_header_x = 0.4,
			form_header_y = 0.4,
			std_inv_x = 0.3,
			std_inv_y = 5.75,
			page_x = 10.75,
			is_lite_mode = false,
			standard_inv_bg = "background9[0.3,5.75;8,4;ui_formbg_9_sliced.png]",
		},
		style_lite = {
			form_header_x = 0.2,
			form_header_y = 0.2,
			std_inv_x = 0.1,
			std_inv_y = 4.60,
			page_x = 10.5,
			is_lite_mode = true,
			standard_inv_bg = "background9[0.1,4.60;8,4;ui_formbg_9_sliced.png]",
		},
		register_page = function(name, def)
			mock_ui.pages[name] = def
		end,
		register_button = function(name, def)
			def.name = name
			if not def.action then
				def.action = function(player)
					mock_ui.set_inventory_formspec(player, name)
				end
			end
			table.insert(mock_ui.buttons, def)
		end,
		get_per_player_formspec = function(_pname)
			return mock_ui.style_full
		end,
		set_inventory_formspec = function(player, page)
			local name = player:get_player_name()
			mock_ui.current_page[name] = page
			local pagedef = mock_ui.pages[page]
			if pagedef and pagedef.get_formspec then
				local res = pagedef.get_formspec(player, mock_ui.style_full)
				player:set_inventory_formspec(res.formspec)
			end
		end,
	}
	_G.unified_inventory = mock_ui

	-- Reload ui module to trigger unified_inventory registration with active mock
	local modpath = core.get_modpath("x_player_armor")
	dofile(modpath .. "/modules/ui.lua")

	-- 2. Verify Theme Injection & Page / Button Registration
	assert(mock_ui.standard_background:find("listcolors%[#00000000;#00000000;#30363d;#10141cf0;#c9d1d9%]"), "Unified Inventory standard_background must be styled with x_player_armor tooltip theme")
	local hooked_ui_fs = mock_ui.get_formspec(create_mock_player("test_uni"), "craft")
	assert(hooked_ui_fs:find("listcolors%[#00000000;#00000000;#30363d;#10141cf0;#c9d1d9%]"), "Hooked Unified Inventory get_formspec must replace un-themed listcolors with dark theme tooltip colors")
	assert(mock_ui.pages["armor"], "Unified Inventory armor page must be registered")
	assert(#mock_ui.buttons >= 1, "Unified Inventory armor button must be registered")
	local armor_btn = nil
	for _, btn in ipairs(mock_ui.buttons) do
		if btn.name == "armor" then
			armor_btn = btn
			break
		end
	end
	assert(armor_btn, "Button with name 'armor' must exist in unified_inventory.buttons")
	assert(armor_btn.type == "image", "Armor button must be type 'image'")
	assert(armor_btn.image == "x_player_armor_icon.png", "Armor button must use x_player_armor_icon.png")
	assert(armor_btn.tooltip, "Armor button must have a localized tooltip")

	-- 3. Verify Full Mode Formspec Output
	local player = create_mock_player("uni_tester")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_diamond"))
	inv:set_stack("armor", 3, ItemStack("x_player_armor:leggings_diamond"))
	inv:set_stack("armor", 4, ItemStack("x_player_armor:boots_diamond"))

	local full_res = mock_ui.pages["armor"].get_formspec(player, mock_ui.style_full)
	assert(full_res.draw_inventory == true, "Full mode must set draw_inventory = true")
	assert(full_res.draw_item_list == true, "Full mode must set draw_item_list = true")
	assert(full_res.formspec:find("listcolors%[#00000000;#00000000;#30363d;#10141cf0;#c9d1d9%]"), "Formspec must include modern theme listcolors")
	assert(full_res.formspec:find("armor_unified_preview"), "Formspec must include 3D player preview element")
	assert(full_res.formspec:find("Drag to rotate 3D view"), "Formspec must include rotation hint")
	assert(full_res.formspec:find("EQUIPPED ARMOR"), "Formspec must include EQUIPPED ARMOR header")
	assert(full_res.formspec:find("tooltip%[[%d%.]+,[%d%.]+;[%d%.]+,[%d%.]+;.*#10141cf0;#c9d1d9%]"), "Vacant armor slot tooltips must define theme bgcolor and accessible textcolor")
	assert(full_res.formspec:find("x_player_armor_stand_head%.png"), "Formspec must include head slot silhouette")
	assert(full_res.formspec:find("x_player_armor_stand_torso%.png"), "Formspec must include torso slot silhouette")
	assert(full_res.formspec:find("x_player_armor_stand_shield%.png"), "Formspec must include shield slot silhouette")
	assert(full_res.formspec:find("x_player_armor_stand_legs%.png"), "Formspec must include legs slot silhouette")
	assert(full_res.formspec:find("x_player_armor_stand_feet%.png"), "Formspec must include feet slot silhouette")
	assert(full_res.formspec:find("x_player_armor_icon%.png"), "Formspec must include aux/trinket slot silhouette")
	assert(full_res.formspec:find("hypertext%[4.95,3.40;5.35,2.10;armor_stats;"), "Formspec must include full mode hypertext stats")
	assert(full_res.formspec:find("ARMOR ATTRIBUTES"), "Formspec must include ARMOR ATTRIBUTES")
	assert(full_res.formspec:find("ACTIVE PERKS"), "Formspec must include ACTIVE PERKS")
	assert(full_res.formspec:find("listring%[detached:uni_tester_armor;armor%]"), "Formspec must include detached inventory listring")
	assert(full_res.formspec:find("listring%[current_player;main%]"), "Formspec must include main inventory listring")

	-- 4. Verify Lite Mode Formspec Output
	local lite_res = x_player_armor.ui.get_unified_inventory_formspec(player, mock_ui.style_lite)
	assert(lite_res.draw_inventory == true, "Lite mode must set draw_inventory = true")
	assert(lite_res.draw_item_list == true, "Lite mode must set draw_item_list = true")
	assert(lite_res.formspec:find("box%[0.10,0.50;3.80,3.95;#161b22ee%]"), "Lite mode must render adjusted preview card box")
	assert(lite_res.formspec:find("model%[0.15,0.55;3.70,3.45;armor_unified_preview;"), "Lite mode must render adjusted 3D preview model")
	assert(lite_res.formspec:find("hypertext%[4.25,2.95;5.90,1.40;armor_stats;"), "Lite mode must render adjusted stats hypertext")

	-- 5. Verify Button Click, Open State & Idle-Skipping Tracking
	armor_btn.action(player)
	assert(mock_ui.current_page["uni_tester"] == "armor", "Button action must switch current page to 'armor'")
	assert(x_player_armor.is_armor_ui_open(player) == true, "is_armor_ui_open must return true when player is viewing armor tab")
	assert(x_player_armor.ui.has_any_open_armor_ui() == true, "has_any_open_armor_ui must return true when player is viewing armor tab")

	-- 6. Verify Formspec Refresh on Wield / Equipment Change
	player.wielded_item = ItemStack("default:sword_steel")
	x_player_armor.ui.refresh_player_formspec(player)
	assert(player:get_inventory_formspec():find("armor_unified_preview"), "refresh_player_formspec must update unified_inventory formspec")

	-- 7. Verify Tab Switching Does Not Hijack Non-Armor Tabs
	mock_ui.current_page["uni_tester"] = "craft"
	-- Simulate receive_fields switching to craft tab
	local receive_fields = core.callbacks.on_player_receive_fields
	for _, fn in ipairs(receive_fields) do
		fn(player, "", {craft = ""})
	end
	assert(x_player_armor.is_armor_ui_open(player) == false, "is_armor_ui_open must return false on craft tab")
	-- Formspec refresh must NOT overwrite the craft tab
	player:set_inventory_formspec("dummy_craft_formspec")
	x_player_armor.ui.refresh_player_formspec(player)
	assert(player:get_inventory_formspec() == "dummy_craft_formspec", "refresh_player_formspec must NOT overwrite non-armor tabs")

	-- 8. Verify Closing Formspec Clears Open State
	for _, fn in ipairs(receive_fields) do
		fn(player, "", {quit = "true"})
	end
	assert(x_player_armor.is_armor_ui_open(player) == false, "is_armor_ui_open must return false after quit")
	assert(x_player_armor.ui.has_any_open_armor_ui() == false, "has_any_open_armor_ui must return false when no UI is open")

	-- Clean up mock
	_G.unified_inventory = nil
	sfinv.enabled = true
end)

test("Unified API Helpers & Dependency Accessors", function()
	-- 1. get_mod_api
	assert(x_player_armor.get_mod_api("non_existent_fake_mod_xyz") == nil, "get_mod_api must return nil for missing mod")
	assert(x_player_armor.get_mod_api("sfinv") ~= nil, "get_mod_api must return sfinv table when present")

	-- 3. get_elements
	local elements = x_player_armor.get_elements()
	assert(type(elements) == "table" and #elements >= 5, "get_elements must return array of elements")
	assert(elements[1] == "head" and elements[2] == "torso", "get_elements must contain default elements")

	-- 4. get_attributes
	local attrs = x_player_armor.get_attributes()
	assert(type(attrs) == "table" and #attrs >= 4, "get_attributes must return array of attributes")
	assert(attrs[1] == "heal" and attrs[2] == "fire", "get_attributes must contain default attributes")

	-- 5. get_fire_nodes
	local fnodes = x_player_armor.get_fire_nodes()
	assert(type(fnodes) == "table", "get_fire_nodes must return a table")

	-- 6. is_reciprocate_damage_enabled
	local is_recip = x_player_armor.is_reciprocate_damage_enabled()
	assert(type(is_recip) == "boolean", "is_reciprocate_damage_enabled must return boolean")

	-- 7. Preallocated table reference identity (zero-allocation guarantee)
	local el1 = x_player_armor.get_elements()
	local el2 = x_player_armor.get_elements()
	assert(el1 == el2, "get_elements must return the exact same preallocated table instance")
	local at1 = x_player_armor.get_attributes()
	local at2 = x_player_armor.get_attributes()
	assert(at1 == at2, "get_attributes must return the exact same preallocated table instance")
end)

test("Architectural Standards, Public API Surface & Downstream Compat", function()
	local player = create_mock_player("solid_hero")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)

	-- 1. Verify x_player_armor.compat orchestrator namespace (SOLID)
	assert(type(x_player_armor.compat) == "table", "x_player_armor.compat table must exist")
	assert(x_player_armor.compat.hud == x_player_armor.compat_hud, "compat.hud must match compat_hud")
	assert(x_player_armor.compat.x_player_api == x_player_armor.compat_x_player_api, "compat.x_player_api must match compat_x_player_api")
	assert(x_player_armor.compat.armor == x_player_armor.compat_armor, "compat.armor must match compat_armor")
	assert(x_player_armor.compat.shields == x_player_armor.compat_shields, "compat.shields must match compat_shields")
	assert(x_player_armor.compat.stand == x_player_armor.compat_stand, "compat.stand must match compat_stand")

	-- 2. Verify public get_equipped_shield on x_player_armor root API (for deathstats / x_bows)
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel"))
	local stack, slot_idx, mat = x_player_armor.get_equipped_shield(player)
	assert(stack ~= nil and stack:get_name() == "x_player_armor:shield_steel", "get_equipped_shield must return equipped shield stack")
	assert(slot_idx == 5, "slot_idx must be 5")
	assert(mat == "steel", "mat must be steel")

	-- 3. Verify get_shield_contact_pos on x_player_armor root API
	local contact_pos = x_player_armor.get_shield_contact_pos(player)
	assert(type(contact_pos) == "table" and contact_pos.x and contact_pos.y and contact_pos.z, "get_shield_contact_pos must return 3D vector")

	-- 4. Verify armor.textures[pname].shield populated for deathstats corpse rendering
	local a_tex = _G.armor.textures["solid_hero"]
	assert(type(a_tex) == "table", "armor.textures must be a table")
	assert(a_tex.shield == "x_player_armor_steel.png", "armor.textures[pname].shield must contain shield texture for deathstats")

	-- 5. Verify armor.config drop & destroy flags match constants (deathstats is_armor_dropped)
	assert(_G.armor.config.drop == x_player_armor.constants.DROP_ON_DEATH, "armor.config.drop must match DROP_ON_DEATH")
	assert(_G.armor.config.destroy == x_player_armor.constants.DESTROY_ON_DEATH, "armor.config.destroy must match DESTROY_ON_DEATH")

	-- 6. Verify numeric slot un-equipping for auxiliary slot 6 via armor:unequip
	inv:set_stack("armor", 6, ItemStack("x_player_armor:shield_wood"))
	assert(not inv:get_stack("armor", 6):is_empty(), "Slot 6 must have wood shield")
	local unequipped_slot6 = _G.armor:unequip(player, 6)
	assert(unequipped_slot6:get_name() == "x_player_armor:shield_wood", "unequip with slot index 6 must return wood shield")
	assert(inv:get_stack("armor", 6):is_empty(), "Slot 6 must now be empty")

	-- 7. Verify utils.material_cache memoization
	assert(x_player_armor.utils.material_cache["x_player_armor:shield_steel"] == "steel", "material_cache must store resolved material")
	assert(x_player_armor.utils.get_item_material("x_player_armor:shield_steel") == "steel", "get_item_material must return cached material")

	-- 8. Verify public UI state helpers on x_player_armor root
	assert(x_player_armor.is_armor_ui_open(player) == false, "is_armor_ui_open must return false initially")
	assert(type(x_player_armor.has_any_open_armor_ui()) == "boolean", "has_any_open_armor_ui must return boolean")
end)

test("Modern Item Tooltips, Short Descriptions & Armor Stand Tooltips", function()
	local mats = {"wood", "cactus", "steel", "bronze", "diamond", "gold", "mithril", "crystal", "nether", "admin"}
	local pieces = {"helmet", "chestplate", "leggings", "boots", "shield"}

	for _, mat in ipairs(mats) do
		for _, piece in ipairs(pieces) do
			local iname = "x_player_armor:" .. piece .. "_" .. mat
			local def = core.registered_tools[iname]
			assert(def, "Tool must be registered: " .. iname)
			assert(def.short_description, "short_description must be set on " .. iname)
			assert(not def.short_description:find("\n"), "short_description must be single-line on " .. iname)
			assert(def.description, "description must be set on " .. iname)
			assert(def.description:find("\n"), "description must be multi-line formatted tooltip on " .. iname)
			assert(def.description:find("Type:"), "description must specify item type on " .. iname)
			assert(def.description:find("Defense:"), "description must specify defense on " .. iname)
			assert(def.description:find("Durability:"), "description must specify durability on " .. iname)
		end
	end

	-- Check enhanced shields
	for _, emat in ipairs({"wood", "cactus"}) do
		local es_name = "x_player_armor:shield_enhanced_" .. emat
		local es_def = core.registered_tools[es_name]
		assert(es_def, "Enhanced shield must be registered: " .. es_name)
		assert(es_def.short_description, "Enhanced shield must have short_description")
		assert(es_def.description:find("Tower Shield"), "Enhanced shield tooltip must identify Tower Shield")
		assert(es_def.description:find("Reinforced Tower Guard"), "Enhanced shield tooltip must detail Reinforced Tower Guard")
	end

	-- Check Armor Stand
	local stand_def = core.registered_nodes["x_player_armor:stand"]
	assert(stand_def, "Stand must be registered")
	assert(stand_def.short_description == "Armor Stand", "Stand short_description must be 'Armor Stand'")
	assert(stand_def.description:find("Wardrobe Management & Quick Swap"), "Stand tooltip must detail wardrobe management and quick swap")

	-- Check third-party auto-enrichment
	x_player_armor.register_armor("custom_mod:helm_obsidian", {
		description = "Obsidian Greathelm",
		groups = {armor_head = 20, armor_uses = 2500, armor_fire = 1},
	})
	local custom_def = core.registered_tools["custom_mod:helm_obsidian"]
	assert(custom_def.short_description == "Obsidian Greathelm", "Custom armor short_description must be set")
	assert(custom_def.description:find("Type: Helmet"), "Custom armor description must be auto-enriched with Type: Helmet")
	assert(custom_def.description:find("%+20%% Damage Reduction"), "Custom armor description must be auto-enriched with defense")
	assert(custom_def.description:find("2500 Uses"), "Custom armor description must have durability")
	assert(custom_def.description:find("Fire Ward"), "Custom armor description must have Fire Ward")
end)

test("Armor Stand Formspec UI, One-Click Wardrobe Swap & Empty Slot Tooltips", function()
	local player = create_mock_player("swap_hero")
	x_player_armor.inventory.init_player_inventory(player)
	local _, pinv = x_player_armor.get_valid_player(player)

	local pos = {x = 10, y = 5, z = 20}
	core.set_node(pos, {name = "x_player_armor:stand"})
	local meta = core.get_meta(pos)
	meta:set_string("owner", "swap_hero")
	local sinv = meta:get_inventory()
	sinv:set_size("armor", 5)

	-- 1. Check Empty Slot Tooltips in Stand Formspec
	local fs_empty = x_player_armor.stand.get_stand_formspec(pos, player)
	assert(fs_empty:find("formspec_version%[7%]"), "Stand formspec must be version 7")
	assert(fs_empty:find("STAND ARMOR"), "Stand formspec must contain STAND ARMOR header")
	assert(fs_empty:find("YOUR ARMOR"), "Stand formspec must contain YOUR ARMOR header")
	assert(fs_empty:find("btn_swap_armor"), "Stand formspec must contain btn_swap_armor button")
	assert(fs_empty:find("btn_take_all"), "Stand formspec must contain btn_take_all button")
	assert(fs_empty:find("Helmet Slot"), "Empty stand slots must display Helmet Slot tooltip")
	assert(fs_empty:find("Chestplate Slot"), "Empty stand slots must display Chestplate Slot tooltip")
	assert(fs_empty:find("Shield Slot"), "Empty stand slots must display Shield Slot tooltip")

	-- 2. Check Empty Slot Tooltips in Player Formspec via ui.render_slots
	local player_fs = x_player_armor.ui.get_formspec(player)
	assert(player_fs:find("Helmet Slot"), "Player empty helmet slot must show tooltip")
	assert(player_fs:find("Chestplate Slot"), "Player empty chestplate slot must show tooltip")

	-- Equip diamond helmet on player, verify vacant chestplate still has tooltip
	pinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	local player_fs_equipped = x_player_armor.ui.get_formspec(player)
	assert(player_fs_equipped:find("Chestplate Slot"), "Vacant chestplate slot must still have tooltip")

	-- 3. Equip full set on player, and different set on stand
	pinv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_diamond"))
	pinv:set_stack("armor", 3, ItemStack("x_player_armor:leggings_diamond"))
	pinv:set_stack("armor", 4, ItemStack("x_player_armor:boots_diamond"))
	pinv:set_stack("armor", 5, ItemStack("x_player_armor:shield_diamond"))
	x_player_armor.set_player_armor(player)

	sinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_steel"))
	sinv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_steel"))
	sinv:set_stack("armor", 3, ItemStack("x_player_armor:leggings_steel"))
	sinv:set_stack("armor", 4, ItemStack("x_player_armor:boots_steel"))
	sinv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel"))
	x_player_armor.stand.update_stand_entity(pos)

	-- 4. Execute Swap Armor via Stand API
	local swap_res = x_player_armor.stand.swap_armor(pos, player)
	assert(swap_res == true, "swap_armor must return true on success")

	-- Verify Player now wears steel
	assert(pinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_steel", "Player must now wear steel helmet")
	assert(pinv:get_stack("armor", 2):get_name() == "x_player_armor:chestplate_steel", "Player must now wear steel chestplate")
	assert(pinv:get_stack("armor", 3):get_name() == "x_player_armor:leggings_steel", "Player must now wear steel leggings")
	assert(pinv:get_stack("armor", 4):get_name() == "x_player_armor:boots_steel", "Player must now wear steel boots")
	assert(pinv:get_stack("armor", 5):get_name() == "x_player_armor:shield_steel", "Player must now hold steel shield")

	-- Verify Stand now holds diamond
	assert(sinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_diamond", "Stand must now hold diamond helmet")
	assert(sinv:get_stack("armor", 2):get_name() == "x_player_armor:chestplate_diamond", "Stand must now hold diamond chestplate")
	assert(sinv:get_stack("armor", 3):get_name() == "x_player_armor:leggings_diamond", "Stand must now hold diamond leggings")
	assert(sinv:get_stack("armor", 4):get_name() == "x_player_armor:boots_diamond", "Stand must now hold diamond boots")
	assert(sinv:get_stack("armor", 5):get_name() == "x_player_armor:shield_diamond", "Stand must now hold diamond shield")

	-- 5. Test Swap via Button Interaction (register_on_player_receive_fields)
	local formname = string.format("x_player_armor:stand_%d_%d_%d", pos.x, pos.y, pos.z)
	for _, fn in ipairs(core.callbacks.on_player_receive_fields) do
		fn(player, formname, {btn_swap_armor = "true"})
	end

	-- Player should get diamond back!
	assert(pinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_diamond", "Player must receive diamond helmet back after second swap")
	assert(sinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_steel", "Stand must receive steel helmet back after second swap")

	-- 6. Test Take All Armor via Button Interaction
	for _, fn in ipairs(core.callbacks.on_player_receive_fields) do
		fn(player, formname, {btn_take_all = "true"})
	end

	-- Stand should now be empty
	for idx = 1, 6 do
		assert(sinv:get_stack("armor", idx):is_empty(), "Stand slot " .. idx .. " must be empty after take-all")
	end

	-- 6b. Verify foreign formspec quit events (such as default:chest) are never intercepted
	local foreign_formname = "default:chest"
	for _, fn in ipairs(core.callbacks.on_player_receive_fields) do
		local res = fn(player, foreign_formname, {quit = "true"})
		assert(res ~= true, "Global on_player_receive_fields must not intercept foreign formspec quit events")
	end

	-- 7. Test Cursed Armor Lock in Swap
	core.register_tool("custom_mod:cursed_helm", {
		description = "Cursed Crown",
		groups = {armor_head = 15, cursed = 1},
	})
	pinv:set_stack("armor", 1, ItemStack("custom_mod:cursed_helm"))
	sinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_gold"))
	local cursed_swap = x_player_armor.stand.swap_armor(pos, player)
	assert(cursed_swap == false, "swap_armor must fail when player has cursed item equipped")
	assert(pinv:get_stack("armor", 1):get_name() == "custom_mod:cursed_helm", "Cursed item must remain on player")
	assert(sinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_gold", "Stand item must remain on stand")

	-- 8. Test Protection / Ownership Check
	local stranger = create_mock_player("stranger_thief")
	x_player_armor.inventory.init_player_inventory(stranger)
	assert(x_player_armor.stand.can_interact(pos, stranger) == false, "Stranger must not have permission to access private stand")
	local stranger_swap = x_player_armor.stand.swap_armor(pos, stranger)
	assert(stranger_swap == false, "Unauthorized player must not be able to swap armor")
	local stranger_take = x_player_armor.stand.take_all_armor(pos, stranger)
	assert(stranger_take == false, "Unauthorized player must not be able to take armor from private stand")
end)

test("Unified Inventory Tooltip Theming, WCAG Accessibility & Zero Redundant Nil Guards", function()
	-- 1. Verify Tooltip Theme Escape Sequence
	local tooltip_str = x_player_armor.utils.format_armor_tooltip({
		title = "Mithril Helmet",
		element = "head",
		material = "mithril",
		level = 18,
		uses = 1800,
		heal = 3,
	})
	assert(tooltip_str:find("\27%(b@#10141cf0%)"), "format_armor_tooltip must prepend theme background escape sequence")

	local stand_tip = x_player_armor.utils.format_armor_stand_tooltip()
	assert(stand_tip:find("\27%(b@#10141cf0%)"), "format_armor_stand_tooltip must prepend theme background escape sequence")

	-- 2. Verify WCAG AA / AAA Accessible Colors
	local ui_colors = x_player_armor.utils.UI_COLORS
	assert(ui_colors.label == "#c9d1d9", "UI_COLORS.label must be high-contrast #c9d1d9 (>10:1 contrast)")
	assert(ui_colors.hint == "#9ecbff", "UI_COLORS.hint must be high-contrast #9ecbff (>9:1 contrast)")
	assert(ui_colors.tooltip_bg == "#10141cf0", "UI_COLORS.tooltip_bg must be #10141cf0")
	assert(ui_colors.tooltip_font == "#c9d1d9", "UI_COLORS.tooltip_font must be #c9d1d9")

	-- Calculate relative luminance and verify WCAG AA contrast >= 4.5:1 against #161b22
	local function hex_to_rgb(hex)
		local clean = hex:gsub("#", "")
		local r = tonumber(clean:sub(1, 2), 16) / 255
		local g = tonumber(clean:sub(3, 4), 16) / 255
		local b = tonumber(clean:sub(5, 6), 16) / 255
		return r, g, b
	end

	local function relative_luminance(r, g, b)
		local function adjust(c)
			return c <= 0.03928 and (c / 12.92) or (((c + 0.055) / 1.055) ^ 2.4)
		end
		return 0.2126 * adjust(r) + 0.7152 * adjust(g) + 0.0722 * adjust(b)
	end

	local bg_lum = relative_luminance(hex_to_rgb("#161b22"))
	for key, color in pairs(ui_colors) do
		if key ~= "tooltip_bg" then
			local r, g, b = hex_to_rgb(color)
			local fg_lum = relative_luminance(r, g, b)
			local contrast = (math.max(fg_lum, bg_lum) + 0.05) / (math.min(fg_lum, bg_lum) + 0.05)
			assert(contrast >= 4.5, string.format("UI_COLORS.%s (%s) must meet WCAG AA contrast (got %.2f:1)", key, color, contrast))
		end
	end

	-- 3. Verify Direct Assignment on Compat Table Without Redundant Nil Guards
	assert(x_player_armor.compat.shields ~= nil, "x_player_armor.compat.shields must be directly assigned")
	assert(x_player_armor.compat.armor ~= nil, "x_player_armor.compat.armor must be directly assigned")
	assert(x_player_armor.compat.stand ~= nil, "x_player_armor.compat.stand must be directly assigned")
	assert(x_player_armor.compat.hud ~= nil, "x_player_armor.compat.hud must be directly assigned")
	assert(x_player_armor.compat.x_player_api ~= nil, "x_player_armor.compat.x_player_api must be directly assigned")
end)

test("Armor Entity Protection, ClearObjects Recovery & Zero on_step Overhead", function()
	-- 1. Zero on_step overhead invariant & on_deactivate registration
	local visual_def = core.registered_entities["x_player_armor:visual"]
	assert(visual_def ~= nil, "x_player_armor:visual must be registered")
	assert(visual_def.on_step == nil, "x_player_armor:visual must have on_step strictly nil for 0 tick overhead")
	assert(type(visual_def.on_deactivate) == "function", "x_player_armor:visual must declare on_deactivate callback")

	local stand_def = core.registered_entities["x_player_armor:stand_entity"]
	assert(stand_def ~= nil, "x_player_armor:stand_entity must be registered")
	assert(stand_def.on_step == nil, "x_player_armor:stand_entity must have on_step strictly nil for 0 tick overhead")
	assert(type(stand_def.on_deactivate) == "function", "x_player_armor:stand_entity must declare on_deactivate callback")

	-- 2. Setup mock player with full diamond armor
	local player_name = "guardian_hero"
	local mock_player = create_mock_player(player_name)
	x_player_armor.inventory.init_player_inventory(mock_player)
	local _, inv = x_player_armor.get_valid_player(mock_player)
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_diamond"))
	inv:set_stack("armor", 3, ItemStack("x_player_armor:leggings_diamond"))
	inv:set_stack("armor", 4, ItemStack("x_player_armor:boots_diamond"))

	-- Initial visual instantiation
	x_player_armor.update_player_visuals(mock_player)
	local pdata = x_player_armor.visuals.player_entities[player_name]
	assert(pdata ~= nil, "player_entities table must exist for player")
	assert(pdata.head and #pdata.head > 0, "Head entities must be spawned")
	assert(pdata.torso and #pdata.torso > 0, "Torso entities must be spawned")
	assert(pdata.legs and #pdata.legs > 0, "Legs entities must be spawned")
	assert(pdata.feet and #pdata.feet > 0, "Feet entities must be spawned")

	-- Store initial object references and verify valid
	local initial_head_obj = pdata.head[1]
	assert(initial_head_obj:is_valid() == true, "Initial piece must be valid")
	local head_luaent = initial_head_obj:get_luaentity()
	assert(head_luaent._player_name == player_name, "Piece entity must record player name")
	assert(head_luaent._intentional_removal == false, "Intentional removal must default to false")

	-- 3. Simulate engine clear_objects (quick mode triggers on_deactivate on active objects)
	core.clear_objects({mode = "quick"})

	-- The original entity is now invalidated
	assert(initial_head_obj:is_valid() == false, "Initial entity must be invalidated by clear_objects")

	-- on_deactivate automatically restored the armor visuals via schedule_player_restore
	local restored_pdata = x_player_armor.visuals.player_entities[player_name]
	assert(restored_pdata ~= nil, "player_entities table must be restored after clear_objects")
	assert(restored_pdata.head and #restored_pdata.head > 0, "Restored head entities must exist")
	local new_head_obj = restored_pdata.head[1]
	assert(new_head_obj:is_valid() == true, "Restored piece must be valid")
	assert(new_head_obj ~= initial_head_obj, "Restored piece must be a fresh ObjectRef")

	-- 4. Protection against external entity deletion (e.g. WorldEdit or admin remove) via on_deactivate
	local pre_external_obj = restored_pdata.torso[1]
	assert(pre_external_obj:is_valid() == true, "Torso piece must be valid before external removal")

	-- External mod or command calls obj:remove() directly without _intentional_removal
	pre_external_obj:remove()
	assert(pre_external_obj:is_valid() == false, "Piece must be removed")

	-- on_deactivate detected unintentional removal and scheduled restoration
	local post_deactivate_pdata = x_player_armor.visuals.player_entities[player_name]
	assert(post_deactivate_pdata ~= nil, "player_entities table must exist")
	local healed_torso_obj = post_deactivate_pdata.torso[1]
	assert(healed_torso_obj:is_valid() == true, "Torso piece must be auto-healed after external removal")
	assert(healed_torso_obj ~= pre_external_obj, "Auto-healed torso piece must be a newly spawned entity")

	-- 5. Intentional removal (e.g. clear_all / logout) must NOT trigger spurious re-spawn
	x_player_armor.visuals.clear_all(player_name)
	assert(x_player_armor.visuals.player_entities[player_name] == nil, "player_entities must be nil after intentional clear_all")

	-- 6. Stand mannequin entity on_deactivate recovery
	local stand_pos = {x = 50, y = 10, z = 50}
	core.set_node(stand_pos, {name = "x_player_armor:stand", param2 = 0})
	local smeta = core.get_meta(stand_pos)
	local sinv = smeta:get_inventory()
	sinv:set_size("armor", 5)
	sinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	x_player_armor.stand.update_stand_entity(stand_pos)

	local stand_objs = core.get_objects_inside_radius(stand_pos, 0.5)
	local stand_ent_obj = nil
	for _, obj in ipairs(stand_objs) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "x_player_armor:stand_entity" then
			stand_ent_obj = obj
			break
		end
	end
	assert(stand_ent_obj ~= nil, "Stand entity must be spawned")
	assert(stand_ent_obj:is_valid() == true, "Stand entity must be valid")

	-- External wipe on stand entity
	stand_ent_obj:remove()
	assert(stand_ent_obj:is_valid() == false, "Stand entity was removed")

	-- on_deactivate auto-restores stand mannequin because node is still x_player_armor:stand
	local new_stand_objs = core.get_objects_inside_radius(stand_pos, 0.5)
	local restored_stand_ent = nil
	for _, obj in ipairs(new_stand_objs) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "x_player_armor:stand_entity" and obj:is_valid() then
			restored_stand_ent = obj
			break
		end
	end
	assert(restored_stand_ent ~= nil, "Stand mannequin must be auto-restored after unintentional removal")
	assert(restored_stand_ent ~= stand_ent_obj, "Restored stand entity must be a newly spawned entity")

	-- 7. Chatcommand /restore_armor_visuals
	local cmd = core.registered_chatcommands["restore_armor_visuals"]
	assert(cmd ~= nil, "/restore_armor_visuals chatcommand must be registered")
	local success, msg = cmd.func("admin", player_name)
	assert(success == true, "/restore_armor_visuals must return true")
	assert(msg:find("Restored armor visuals for player"), "Must confirm player restoration")

	local all_success, all_msg = cmd.func("admin", "")
	assert(all_success == true, "/restore_armor_visuals with empty param must return true")
	assert(all_msg:find("Restored armor visuals for all connected players"), "Must confirm all players restoration")

	-- 8. Public API helpers
	assert(type(x_player_armor.restore_all_player_visuals) == "function", "restore_all_player_visuals must be exposed on API")
	assert(type(x_player_armor.schedule_player_visual_restore) == "function", "schedule_player_visual_restore must be exposed on API")
end)

test("In-World Armor Stand: Dual Variants, Shift+LMB Raycast Take/Swap, glTF 10x Scale & Shields", function()
	-- 1. Registration of Unlocked and Locked variants
	local pub_def = core.registered_nodes["x_player_armor:stand"]
	local lock_def = core.registered_nodes["x_player_armor:locked_stand"]
	assert(pub_def ~= nil, "Public stand must be registered")
	assert(lock_def ~= nil, "Locked stand must be registered")
	assert(pub_def.short_description == "Armor Stand", "Public stand short description must match")
	assert(lock_def.short_description == "Locked Armor Stand", "Locked stand short description must match")
	assert(pub_def.visual_scale == 1.0, "glTF node visual_scale must be 1.0 (10 units = 1 node)")
	assert(lock_def.visual_scale == 1.0, "glTF locked node visual_scale must be 1.0")
	assert(pub_def.tiles[1] == "x_player_armor_stand_shared.png", "Public stand tile must be x_player_armor_stand_shared.png")
	assert(pub_def.inventory_image == "x_player_armor_stand_inv.png", "Public stand inventory image must be x_player_armor_stand_inv.png")
	assert(pub_def.wield_image == "x_player_armor_stand_inv.png", "Public stand wield image must be x_player_armor_stand_inv.png")
	assert(lock_def.tiles[1] == "x_player_armor_stand_locked.png", "Locked stand tile must be x_player_armor_stand_locked.png")
	assert(lock_def.inventory_image == "x_player_armor_stand_locked_inv.png", "Locked stand inventory image must be x_player_armor_stand_locked_inv.png")
	assert(lock_def.wield_image == "x_player_armor_stand_locked_inv.png", "Locked stand wield image must be x_player_armor_stand_locked_inv.png")
	assert(pub_def.sounds ~= nil and pub_def.sounds.dig ~= nil and pub_def.sounds.dig.name == "x_player_armor_stand_dig", "Public stand dig sound must be x_player_armor_stand_dig")
	assert(pub_def.sounds.dug.name == "x_player_armor_stand_dug", "Public stand dug sound must be x_player_armor_stand_dug")
	assert(pub_def.sounds.place.name == "x_player_armor_stand_place", "Public stand place sound must be x_player_armor_stand_place")
	assert(pub_def.sounds.footstep.name == "x_player_armor_stand_footstep", "Public stand footstep sound must be x_player_armor_stand_footstep")
	assert(lock_def.sounds ~= nil and lock_def.sounds.dig ~= nil and lock_def.sounds.dig.name == "x_player_armor_stand_dig", "Locked stand dig sound must be x_player_armor_stand_dig")
	assert(lock_def.sounds.dug.name == "x_player_armor_stand_dug", "Locked stand dug sound must be x_player_armor_stand_dug")
	assert(lock_def.sounds.place.name == "x_player_armor_stand_place", "Locked stand place sound must be x_player_armor_stand_place")
	assert(lock_def.sounds.footstep.name == "x_player_armor_stand_footstep", "Locked stand footstep sound must be x_player_armor_stand_footstep")

	-- 2. Legacy Aliases
	assert(core.registered_aliases["3d_armor_stand:armor_stand"] == "x_player_armor:stand", "3d_armor_stand:armor_stand alias must map to stand")
	assert(core.registered_aliases["3d_armor_stand:locked_armor_stand"] == "x_player_armor:locked_stand", "3d_armor_stand:locked_armor_stand alias must map to locked_stand")
	assert(core.registered_aliases["3d_armor_stand:armor_stand_locked"] == "x_player_armor:locked_stand", "3d_armor_stand:armor_stand_locked alias must map to locked_stand")

	-- 3. Crafting Recipes
	local found_locked_craft = false
	for _, c in ipairs(core.registered_crafts) do
		if c.output == "x_player_armor:locked_stand" then
			found_locked_craft = true
			break
		end
	end
	assert(found_locked_craft == true, "Crafting recipe for x_player_armor:locked_stand must be registered")

	-- 4. Dual Security Model (Public vs Owner-Locked)
	local p_owner = create_mock_player("knight_owner")
	local p_stranger = create_mock_player("wandering_stranger")
	local p_admin = create_mock_player("server_admin")
	core.set_player_privs("server_admin", {protection_bypass = true})

	local pos_pub = {x = 50, y = 5, z = 50}
	core.set_node(pos_pub, {name = "x_player_armor:stand", param2 = 0})
	pub_def.on_construct(pos_pub)
	pub_def.after_place_node(pos_pub, p_owner)

	local pos_lock = {x = 60, y = 5, z = 60}
	core.set_node(pos_lock, {name = "x_player_armor:locked_stand", param2 = 0})
	lock_def.on_construct(pos_lock)
	lock_def.after_place_node(pos_lock, p_owner)

	-- Public stand: Stranger can interact if unprotected
	assert(x_player_armor.stand.can_interact(pos_pub, p_stranger, false) == true, "Stranger must be allowed to access public stand")
	-- Locked stand: Stranger is blocked, owner and admin are allowed
	assert(x_player_armor.stand.can_interact(pos_lock, p_stranger, true) == false, "Stranger must be blocked from locked stand")
	assert(x_player_armor.stand.can_interact(pos_lock, p_owner, true) == true, "Owner must be allowed to access locked stand")
	assert(x_player_armor.stand.can_interact(pos_lock, p_admin, true) == true, "Admin with bypass must be allowed to access locked stand")

	-- 5. Raycast Slot Calculation (Vertical & Lateral 3D)
	local slot_head = x_player_armor.stand.get_slot_from_intersection(pos_pub, {x = 50, y = 6.0, z = 50}) -- rel_y = 1.0
	local slot_torso = x_player_armor.stand.get_slot_from_intersection(pos_pub, {x = 50, y = 5.5, z = 50}) -- rel_y = 0.5, lateral = 0.0
	local slot_wield = x_player_armor.stand.get_slot_from_intersection(pos_pub, {x = 50.3, y = 5.5, z = 50}) -- right arm (lateral = +0.3)
	local slot_shield = x_player_armor.stand.get_slot_from_intersection(pos_pub, {x = 49.7, y = 5.5, z = 50}) -- left arm (lateral = -0.3)
	local slot_legs = x_player_armor.stand.get_slot_from_intersection(pos_pub, {x = 50, y = 5.0, z = 50}) -- rel_y = 0.0
	local slot_boots = x_player_armor.stand.get_slot_from_intersection(pos_pub, {x = 50, y = 4.6, z = 50}) -- rel_y = -0.4
	assert(slot_head == 1, "Head raycast must target slot 1")
	assert(slot_torso == 2, "Torso raycast must target slot 2")
	assert(slot_wield == 6, "Right arm raycast must target slot 6 (Weapon)")
	assert(slot_shield == 5, "Left arm raycast must target slot 5 (Shield)")
	assert(slot_legs == 3, "Legs raycast must target slot 3")
	assert(slot_boots == 4, "Boots raycast must target slot 4")

	-- 6. Shift + LMB Targeted Take / Swap
	x_player_armor.inventory.init_player_inventory(p_owner)
	local _, pinv = x_player_armor.get_valid_player(p_owner)
	local smeta = core.get_meta(pos_pub)
	local sinv = smeta:get_inventory()

	-- Scenario A: Stand has steel helmet, player has diamond helmet -> SWAP
	sinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_steel"))
	pinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	x_player_armor.set_player_armor(p_owner)

	local pt_head = {intersection_point = {x = 50, y = 6.0, z = 50}}
	local handled = x_player_armor.stand.handle_sneak_punch(pos_pub, p_owner, pt_head, false)
	assert(handled == true, "Sneak punch must be handled")
	assert(pinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_steel", "Player must receive steel helmet from swap")
	assert(sinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_diamond", "Stand must receive diamond helmet from swap")

	-- Scenario B: Stand has diamond helmet, player head slot is empty -> TAKE
	pinv:set_stack("armor", 1, ItemStack(""))
	x_player_armor.set_player_armor(p_owner)
	x_player_armor.stand.handle_sneak_punch(pos_pub, p_owner, pt_head, false)
	assert(pinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_diamond", "Player must take diamond helmet from stand")
	assert(sinv:get_stack("armor", 1):is_empty() == true, "Stand head slot must now be empty")

	-- Scenario C: Stand head slot is empty, player has steel helmet -> EQUIP
	pinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_steel"))
	x_player_armor.set_player_armor(p_owner)
	x_player_armor.stand.handle_sneak_punch(pos_pub, p_owner, pt_head, false)
	assert(sinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_steel", "Stand must receive helmet from player")
	assert(pinv:get_stack("armor", 1):is_empty() == true, "Player head slot must now be empty")

	-- Scenario D: Stand has steel sword in slot 6, player holds diamond sword in hand -> SWAP WEAPON
	sinv:set_stack("armor", 6, ItemStack("default:sword_steel"))
	p_owner:set_wielded_item(ItemStack("default:sword_diamond"))
	local pt_wield = {intersection_point = {x = 50.3, y = 5.5, z = 50}}
	local handled_wield = x_player_armor.stand.handle_sneak_punch(pos_pub, p_owner, pt_wield, false)
	assert(handled_wield == true, "Sneak punch on weapon slot must be handled")
	assert(p_owner:get_wielded_item():get_name() == "default:sword_steel", "Player must wield steel sword after swap")
	assert(sinv:get_stack("armor", 6):get_name() == "default:sword_diamond", "Stand must hold diamond sword in slot 6 after swap")

	-- 7. Shield & Weapon Mounting in Single-Entity Preview Mesh
	local stand_ent = x_player_armor.stand.get_stand_entity(pos_pub)
	assert(stand_ent ~= nil, "Stand entity must exist")
	assert(x_player_armor.stand.get_stand_shield(pos_pub) == nil, "Standalone child shield entity must not exist (single entity architecture)")

	-- Mount shield into slot 5
	sinv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel"))
	x_player_armor.stand.update_stand_entity(pos_pub)
	local tex_shield = stand_ent:get_properties().textures
	assert(tex_shield[7] == "x_player_armor_steel.png", "Slot 6 material (Shield_Standard, Lua index 7) must be steel shield texture")
	assert(tex_shield[8] == "blank.png", "Slot 7 material (Shield_Tower, Lua index 8) must remain blank")

	-- Mount weapon into slot 6
	sinv:set_stack("armor", 6, ItemStack("default:sword_steel"))
	x_player_armor.stand.update_stand_entity(pos_pub)
	local tex_wield = stand_ent:get_properties().textures
	assert(tex_wield[9] == "default_tool_steelsword.png", "Slot 8 material (Wielditem, Lua index 9) must be steel sword texture")

	-- Remove shield and weapon, verify textures reset to blank.png
	sinv:set_stack("armor", 5, ItemStack(""))
	sinv:set_stack("armor", 6, ItemStack(""))
	x_player_armor.stand.update_stand_entity(pos_pub)
	local tex_clean = stand_ent:get_properties().textures
	assert(tex_clean[7] == "blank.png", "Shield material must reset to blank.png")
	assert(tex_clean[9] == "blank.png", "Wielditem material must reset to blank.png")

	-- 8. Screwdriver Rotation (on_rotate)
	local rot_node = core.get_node(pos_pub)
	assert(rot_node.param2 == 0, "Initial param2 must be 0")
	local rot_ok = pub_def.on_rotate(pos_pub, rot_node, p_owner, 1)
	assert(rot_ok == true, "on_rotate must return true for mode 1")
	local post_rot_node = core.get_node(pos_pub)
	assert(post_rot_node.param2 == 1, "Rotated param2 must be 1")

	-- 9. 3D Armor Stand Global Compatibility Shim
	local compat = _G["3d_armor_stand"]
	assert(compat ~= nil, "Global 3d_armor_stand shim must exist")
	assert(type(compat.get_stand_object) == "function", "compat.get_stand_object must exist")
	assert(type(compat.drop_armor) == "function", "compat.drop_armor must exist")
	assert(type(compat.has_locked_armor_stand_privilege) == "function", "compat.has_locked_armor_stand_privilege must exist")

	local obj_found = compat.get_stand_object(pos_pub)
	assert(obj_found ~= nil and obj_found:is_valid(), "compat.get_stand_object must find the stand mannequin")

	-- Test compat drop_armor
	sinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_steel"))
	compat.drop_armor(pos_pub)
	assert(sinv:get_stack("armor", 1):is_empty() == true, "drop_armor must empty the stand inventory")

	-- Test locked privilege check
	local lock_meta = core.get_meta(pos_lock)
	assert(compat.has_locked_armor_stand_privilege(lock_meta, p_owner) == true, "Owner must have locked stand privilege")
	assert(compat.has_locked_armor_stand_privilege(lock_meta, p_stranger) == false, "Stranger must not have locked stand privilege")
	assert(compat.has_locked_armor_stand_privilege(lock_meta, p_admin) == true, "Admin must have locked stand privilege")
end)

test("Armor Stand Formspec Slot 6 Shift-Click Circular Loop & Dynamic Resize", function()
	local player = create_mock_player("loop_tester")
	x_player_armor.inventory.init_player_inventory(player)
	local _, pinv = x_player_armor.get_valid_player(player)
	local minv = player:get_inventory()

	local pos = {x = 140, y = 10, z = 140}
	core.set_node(pos, {name = "x_player_armor:stand"})
	local meta = core.get_meta(pos)
	meta:set_string("owner", "loop_tester")
	local sinv = meta:get_inventory()
	sinv:set_size("armor", 5)

	-- 1. Dynamic inventory resizing on existing 5-slot stands
	local fs = x_player_armor.stand.get_stand_formspec(pos, player)
	assert(sinv:get_size("armor") == 6, "get_stand_formspec must auto-migrate armor stand inventory to 6 slots")
	assert(fs:find("listring%[nodemeta:140,10,140;armor%]"), "Formspec must include stand listring")
	assert(fs:find("listring%[detached:loop_tester_armor;armor%]"), "Formspec must include player armor listring")
	assert(fs:find("listring%[current_player;main%]"), "Formspec must include player inventory listring")

	local stand_node = core.registered_nodes["x_player_armor:stand"]
	assert(stand_node, "Stand node definition must exist")

	-- 2. Circular Shift-Click Loop for Weapons (Stand Slot 6 -> Player Slot 6 -> Main -> Stand Slot 6)
	local sword = ItemStack("default:sword_steel")
	assert(x_player_armor.stand.is_valid_stand_item(sword, 6) == true, "Stand slot 6 must accept sword")
	assert(x_player_armor.inventory.is_valid_slot_item(sword, 6) == true, "Player armor slot 6 must accept sword")

	-- Initial placement into Stand Slot 6
	assert(stand_node.allow_metadata_inventory_put(pos, "armor", 6, sword, player) == 1, "Stand allow_metadata_inventory_put must accept sword in slot 6")
	sinv:set_stack("armor", 6, sword)

	-- Leg 1: Shift-Click from Stand Slot 6 to Player Armor (detached:loop_tester_armor;armor)
	assert(pinv.callbacks.allow_put(pinv, "armor", 6, sword, player) == 1, "Player armor allow_put must accept sword in slot 6 from stand")
	sinv:set_stack("armor", 6, ItemStack(""))
	pinv:set_stack("armor", 6, sword)
	assert(sinv:get_stack("armor", 6):is_empty(), "Stand slot 6 must be empty after shift-click to player")
	assert(pinv:get_stack("armor", 6):get_name() == "default:sword_steel", "Player slot 6 must contain sword")

	-- Leg 2: Shift-Click from Player Armor Slot 6 to Main Inventory (current_player;main)
	assert(minv:room_for_item("main", sword) == true, "Main inventory must have room for sword")
	pinv:set_stack("armor", 6, ItemStack(""))
	local leftover = minv:add_item("main", sword)
	assert(leftover:is_empty(), "Main inventory must take full sword stack")
	assert(pinv:get_stack("armor", 6):is_empty(), "Player slot 6 must be empty after shift-click to main")

	-- Leg 3: Shift-Click from Main Inventory to Stand Slot 6 (nodemeta:140,10,140;armor)
	assert(stand_node.allow_metadata_inventory_put(pos, "armor", 6, sword, player) == 1, "Stand allow_metadata_inventory_put must accept sword from main")
	sinv:set_stack("armor", 6, sword)
	assert(sinv:get_stack("armor", 6):get_name() == "default:sword_steel", "Stand slot 6 must contain sword after circular loop")

	-- 3. Circular Shift-Click Loop for Accessories / Extra Armor (Stand Slot 6 -> Player Slot 6 -> Main -> Stand Slot 6)
	local shield = ItemStack("x_player_armor:shield_wood")
	assert(x_player_armor.stand.is_valid_stand_item(shield, 6) == true, "Stand slot 6 must accept shield/accessory")
	assert(x_player_armor.inventory.is_valid_slot_item(shield, 6) == true, "Player armor slot 6 must accept shield/accessory")

	-- Occupy primary shield slot 5 on both stand and player to test slot 6 auxiliary routing
	sinv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel"))
	pinv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel"))

	-- Place auxiliary shield in Stand Slot 6
	sinv:set_stack("armor", 6, shield)

	-- Leg 1: Shift-Click from Stand Slot 6 to Player Armor Slot 6
	assert(pinv.callbacks.allow_put(pinv, "armor", 6, shield, player) == 1, "Player armor allow_put must accept shield in slot 6")
	sinv:set_stack("armor", 6, ItemStack(""))
	pinv:set_stack("armor", 6, shield)
	assert(pinv:get_stack("armor", 6):get_name() == "x_player_armor:shield_wood", "Player slot 6 must contain auxiliary shield")

	-- Leg 2: Shift-Click from Player Armor Slot 6 to Main Inventory
	assert(minv:room_for_item("main", shield) == true, "Main inventory must have room for shield")
	pinv:set_stack("armor", 6, ItemStack(""))
	local shield_leftover = minv:add_item("main", shield)
	assert(shield_leftover:is_empty(), "Main inventory must take full shield stack")

	-- Leg 3: Shift-Click from Main Inventory back to Stand Slot 6 (since slot 5 is occupied)
	assert(stand_node.allow_metadata_inventory_put(pos, "armor", 6, shield, player) == 1, "Stand allow_metadata_inventory_put must accept shield in slot 6")
	sinv:set_stack("armor", 6, shield)
	assert(sinv:get_stack("armor", 6):get_name() == "x_player_armor:shield_wood", "Stand slot 6 must receive auxiliary shield back")
end)

test("Armor Stand Enhancements: Backface Culling, Orientation, Raycast, Shift+LMB Armor Swap & UI Formspec", function()
	local player = create_mock_player("stand_tester")
	x_player_armor.inventory.init_player_inventory(player)
	local _, pinv = x_player_armor.get_valid_player(player)

	local pos = {x = 160, y = 5, z = 160}
	core.set_node(pos, {name = "x_player_armor:stand", param2 = 0})
	local meta = core.get_meta(pos)
	meta:set_string("owner", "stand_tester")
	local sinv = meta:get_inventory()
	sinv:set_size("armor", 6)

	-- 1. Backface Culling & Arms Texture Validation
	sinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_steel"))
	sinv:set_stack("armor", 6, ItemStack("default:sword_steel"))
	x_player_armor.stand.update_stand_entity(pos)

	local ent = x_player_armor.stand.get_stand_entity(pos)
	assert(ent ~= nil, "Stand entity must exist")
	local props = ent:get_properties()
	assert(props.backface_culling == false, "Stand entity must have backface_culling set to false")
	assert(props.textures[1] == "blank.png", "Stand entity must use blank.png for Material 1 (arms are in node mesh)")

	-- Reset stand items
	sinv:set_stack("armor", 1, ItemStack(""))
	sinv:set_stack("armor", 6, ItemStack(""))
	x_player_armor.stand.update_stand_entity(pos)
	assert(ent:get_properties().textures[1] == "blank.png", "Stand entity must retain blank.png for Material 1 when empty")

	-- 2. Yaw Calculation: Stand Mannequin Faces Front Towards Player
	local stand_node = core.registered_nodes["x_player_armor:stand"]
	assert(stand_node ~= nil, "Stand node definition must exist")
	-- Placing looking south (dir = {0,0,-1}, param2 = 0)
	local placed_item = ItemStack("x_player_armor:stand")
	player:set_look_dir(vector.new(0, 0, -1))
	local ppos = {x = 160, y = 6, z = 160}
	stand_node.after_place_node(ppos, player, placed_item, {under = {x = 160, y = 5, z = 160}, above = ppos, type = "node"})
	local placed_ent = x_player_armor.stand.get_stand_entity(ppos)
	assert(placed_ent ~= nil, "Placed stand entity must exist")
	local expected_yaw = (core.dir_to_yaw(vector.new(0, 0, -1)) + math.pi) % (2 * math.pi)
	assert(math.abs(placed_ent:get_yaw() - expected_yaw) < 0.001, "Mannequin yaw must face opposite of placement look_dir towards player")

	-- 3. Raycast AABB & Spatial Slot Selection
	-- Helmet level: y >= pos.y + 0.65
	local hit_head = {x = 160, y = 5.85, z = 160}
	local pt_head = {intersection_point = hit_head}
	sinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	x_player_armor.stand.handle_sneak_punch(pos, player, pt_head, false)
	assert(sinv:get_stack("armor", 1):is_empty(), "Stand helmet must be taken via Shift+LMB head hit")
	assert(pinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_diamond", "Player must receive helmet")

	-- Torso level: y between 0.15 and 0.65, lateral within 0.15
	local hit_torso = {x = 160, y = 5.4, z = 160}
	local pt_torso = {intersection_point = hit_torso}
	sinv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_diamond"))
	x_player_armor.stand.handle_sneak_punch(pos, player, pt_torso, false)
	assert(sinv:get_stack("armor", 2):is_empty(), "Stand chestplate must be taken via Shift+LMB torso hit")
	assert(pinv:get_stack("armor", 2):get_name() == "x_player_armor:chestplate_diamond", "Player must receive chestplate")

	-- Leggings level: y between -0.25 and 0.15
	local hit_legs = {x = 160, y = 5.0, z = 160}
	local pt_legs = {intersection_point = hit_legs}
	sinv:set_stack("armor", 3, ItemStack("x_player_armor:leggings_diamond"))
	x_player_armor.stand.handle_sneak_punch(pos, player, pt_legs, false)
	assert(sinv:get_stack("armor", 3):is_empty(), "Stand leggings must be taken via Shift+LMB legs hit")
	assert(pinv:get_stack("armor", 3):get_name() == "x_player_armor:leggings_diamond", "Player must receive leggings")

	-- Boots level: y < -0.25
	local hit_feet = {x = 160, y = 4.65, z = 160}
	local pt_feet = {intersection_point = hit_feet}
	sinv:set_stack("armor", 4, ItemStack("x_player_armor:boots_diamond"))
	x_player_armor.stand.handle_sneak_punch(pos, player, pt_feet, false)
	assert(sinv:get_stack("armor", 4):is_empty(), "Stand boots must be taken via Shift+LMB feet hit")
	assert(pinv:get_stack("armor", 4):get_name() == "x_player_armor:boots_diamond", "Player must receive boots")

	-- Analytical Fallback when intersection_point is nil (engine raycast / AABB slab solver)
	player:set_pos(vector.new(160, 5.5, 163))
	player:set_look_dir(vector.new(0, -0.2, -1))
	local resolved = x_player_armor.stand.resolve_stand_intersection(pos, player, {type = "node", under = pos})
	assert(resolved ~= nil, "resolve_stand_intersection must resolve intersection against stand selection box")

	-- 4. Shift+LMB Armor Swap & RMB Wardrobe UI Test
	sinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	sinv:set_stack("armor", 6, ItemStack("default:sword_diamond"))
	pinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_steel"))
	player:set_wielded_item(ItemStack("default:sword_steel"))
	player.controls = {sneak = true}

	-- Trigger Shift + LMB on_punch on stand node
	local punch_res = stand_node.on_punch(pos, {name = "x_player_armor:stand"}, player, {type = "node", under = pos})
	assert(punch_res == true, "Shift + LMB on_punch must execute armor swap")
	assert(pinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_diamond", "Player must receive diamond helmet from stand on Shift+LMB")
	assert(sinv:get_stack("armor", 1):get_name() == "x_player_armor:helmet_steel", "Stand must receive steel helmet from player on Shift+LMB")
	assert(player:get_wielded_item():get_name() == "default:sword_diamond", "Player wield must receive diamond sword from stand on Shift+LMB")
	assert(sinv:get_stack("armor", 6):get_name() == "default:sword_steel", "Stand slot 6 must receive steel sword from player on Shift+LMB")

	-- RMB on stand opens formspec (does not trigger sneak swap)
	stand_node.on_rightclick(pos, {name = "x_player_armor:stand"}, player, ItemStack(""))
	player.controls = {}

	-- 5. Formspec UI Layout & Close Button
	local fs = x_player_armor.stand.get_stand_formspec(pos, player)
	assert(fs:find("formspec_version%[7%]"), "Stand formspec must be version 7")
	assert(fs:find("button_exit%[10.42,0.48;0.52,0.54;btn_close;X%]"), "Stand formspec must contain close button_exit X")
	assert(fs:find("gui_hb_bg.png"), "Stand formspec must include gui_hb_bg.png slot backgrounds for hotbar")
	assert(fs:find("#0d1117"), "Stand formspec must use dark background #0d1117")
	assert(fs:find("#161b22"), "Stand formspec must use card background #161b22")
	assert(fs:find("STAND ARMOR"), "Stand formspec must contain STAND ARMOR card")
	assert(fs:find("YOUR ARMOR"), "Stand formspec must contain YOUR ARMOR card")
	-- Inventory layout: hotbar is above player inventory and without labels
	local pos_hb = fs:find("list%[current_player;main;1.275,5.75;8,1;0%]")
	local pos_inv = fs:find("list%[current_player;main;1.275,7.05;8,3;8%]")
	assert(pos_hb ~= nil, "Stand formspec must render player hotbar")
	assert(pos_inv ~= nil, "Stand formspec must render player main inventory")
	assert(pos_hb < pos_inv, "Player hotbar must appear above main inventory")
	assert(fs:find("PLAYER INVENTORY") == nil, "Stand formspec must not have PLAYER INVENTORY title/label")
	assert(fs:find("HOTBAR") == nil, "Stand formspec must not have HOTBAR title/label")

	-- Clean ASCII button labels without unicode symbols
	assert(fs:find("button%[5.2,2.05;1.2,1.0;btn_swap_armor;Swap%]"), "Stand formspec must contain Swap button without symbols")
	assert(fs:find("button%[5.2,3.35;1.2,1.0;btn_take_all;Take%]"), "Stand formspec must contain Take button without symbols")

	-- Button styling: theme-consistent borders, background colors, and hover/pressed states
	assert(fs:find("style%[btn_swap_armor;bgcolor=#172b4d;textcolor=#58a6ff;font=bold;border=true;borderwidth=1;bordercolor=#388bfd%]"), "btn_swap_armor must have theme border and colors")
	assert(fs:find("style%[btn_swap_armor:hover;bgcolor=#1f4273;textcolor=#ffffff;bordercolor=#79c0ff%]"), "btn_swap_armor must have hover state styling")
	assert(fs:find("style%[btn_swap_armor:pressed;bgcolor=#0e1c33;textcolor=#388bfd;bordercolor=#1f6feb%]"), "btn_swap_armor must have pressed state styling")
	assert(fs:find("style%[btn_take_all;bgcolor=#21262d;textcolor=#c9d1d9;font=bold;border=true;borderwidth=1;bordercolor=#30363d%]"), "btn_take_all must have theme border and colors")
	assert(fs:find("style%[btn_take_all:hover;bgcolor=#30363d;textcolor=#ffffff;bordercolor=#8b949e%]"), "btn_take_all must have hover state styling")
	assert(fs:find("style%[btn_take_all:pressed;bgcolor=#161b22;textcolor=#8b949e;bordercolor=#484f58%]"), "btn_take_all must have pressed state styling")

	-- Close button handling in on_receive_fields
	local close_handled = stand_node.on_receive_fields(pos, "stand_form", {btn_close = "true"}, player)
	assert(close_handled == true, "Stand on_receive_fields must handle btn_close")

	-- 6. Slot 6 Armor Filtering (Prevent body armor pieces from occupying weapon slot)
	local helmet = ItemStack("x_player_armor:helmet_steel")
	local chestplate = ItemStack("x_player_armor:chestplate_steel")
	local leggings = ItemStack("x_player_armor:leggings_steel")
	local boots = ItemStack("x_player_armor:boots_steel")
	local sword = ItemStack("default:sword_steel")
	assert(x_player_armor.stand.is_valid_stand_item(helmet, 6) == false, "Slot 6 must reject helmet")
	assert(x_player_armor.stand.is_valid_stand_item(chestplate, 6) == false, "Slot 6 must reject chestplate")
	assert(x_player_armor.stand.is_valid_stand_item(leggings, 6) == false, "Slot 6 must reject leggings")
	assert(x_player_armor.stand.is_valid_stand_item(boots, 6) == false, "Slot 6 must reject boots")
	assert(x_player_armor.stand.is_valid_stand_item(sword, 6) == true, "Slot 6 must accept sword")
end)

test("Extended Armor Registration API: Custom Models, Transforms, Audio & Attribute Fallbacks", function()
	-- 1. Register armor piece with custom 3D mesh, bone transforms, custom sounds, and legacy attribute fallbacks
	x_player_armor.register_armor("mymod:crown_gold", {
		description = "Golden Crown",
		element = "head",
		level = 25,
		material = "gold",
		mesh = "mymod_crown.glb",
		transforms = {
			head = {bone = "Head", pos = {x = 0, y = 0.5, z = 0}, rot = {x = 0, y = 0, z = 0}, scale = {x = 1.05, y = 1.05, z = 1.05}},
		},
		glow = 8,
		sound_equip = "mymod_crown_equip",
		sound_unequip = "mymod_crown_unequip",
		sound_hit = "mymod_crown_hit",
		sound_break = "mymod_crown_break",
		heal = 5,
		fire = 2,
		water = 1,
		feather = 3,
		speed = 0.15,
		jump = 0.20,
		gravity = -0.10,
		thorns = true,
	})

	local reg_def = x_player_armor.registered_armors["mymod:crown_gold"]
	assert(reg_def ~= nil, "Registered armor definition must exist")
	assert(reg_def.groups.armor_head == 25, "Level must populate groups.armor_head")
	assert(reg_def.armor_groups.fleshy == 25, "Level must populate armor_groups.fleshy")
	assert(reg_def.groups.armor_heal == 5, "Heal must populate groups.armor_heal")
	assert(reg_def.groups.armor_fire == 2, "Fire must populate groups.armor_fire")
	assert(reg_def.groups.armor_water == 1, "Water must populate groups.armor_water")
	assert(reg_def.groups.armor_feather == 3, "Feather must populate groups.armor_feather")
	assert(reg_def.groups.physics_speed == 0.15, "Speed must populate groups.physics_speed")
	assert(reg_def.groups.physics_jump == 0.20, "Jump must populate groups.physics_jump")
	assert(reg_def.groups.physics_gravity == -0.10, "Gravity must populate groups.physics_gravity")
	assert(reg_def.groups.armor_material_gold == 1, "Material must populate groups.armor_material_gold")
	assert(reg_def.reciprocate_damage == true, "Thorns must normalize reciprocate_damage")
	assert(reg_def.sounds.equip == "mymod_crown_equip", "Custom equip sound must normalize to sounds.equip")
	assert(reg_def.sounds.unequip == "mymod_crown_unequip", "Custom unequip sound must normalize to sounds.unequip")
	assert(reg_def.sounds.hit == "mymod_crown_hit", "Custom hit sound must normalize to sounds.hit")
	assert(reg_def.sounds.break_sound == "mymod_crown_break", "Custom break sound must normalize to sounds.break_sound")

	-- 2. Verify custom visual mesh attachment in visuals.lua
	local player = create_mock_player("custom_armor_hero")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)

	inv:set_stack("armor", 1, ItemStack("mymod:crown_gold"))
	x_player_armor.visuals.update_player_visuals(player)

	local player_ents = x_player_armor.visuals.player_entities["custom_armor_hero"]
	assert(player_ents ~= nil and player_ents.head ~= nil, "Head visual entities must be spawned")
	local head_ent = player_ents.head[1]
	assert(head_ent ~= nil, "Visual entity reference must exist")
	local ent_props = head_ent:get_properties()
	assert(ent_props.mesh == "mymod_crown.glb", "Visual entity must use custom mesh 'mymod_crown.glb'")
	assert(ent_props.glow == 8, "Visual entity must have custom glow = 8")
	assert(ent_props.visual_size.x == 1.05, "Visual entity must reflect custom scale")

	-- 3. Verify custom pieces (sleeveless tunic omitting sleeve meshes)
	x_player_armor.register_armor("mymod:tunic_sleeveless", {
		description = "Sleeveless Tunic",
		element = "torso",
		level = 10,
		mesh = "mymod_tunic.glb",
		pieces = {"torso"}, -- Only torso, omit sleeve_l and sleeve_r
	})

	inv:set_stack("armor", 2, ItemStack("mymod:tunic_sleeveless"))
	x_player_armor.visuals.update_player_visuals(player)

	local torso_ents = player_ents.torso
	assert(torso_ents ~= nil, "Torso entities must exist")
	assert(#torso_ents == 1, "Sleeveless tunic must spawn exactly 1 entity (no sleeves)")
	assert(torso_ents[1]:get_properties().mesh == "mymod_tunic.glb", "Torso entity must use 'mymod_tunic.glb'")

	-- 4. Verify custom equip sound playback
	core.sounds_played = {}
	x_player_armor.equip(player, ItemStack("mymod:crown_gold"))
	local last_snd = core.sounds_played[#core.sounds_played]
	assert(last_snd ~= nil and last_snd.name == "mymod_crown_equip", "Equip must play custom sound 'mymod_crown_equip'")

	-- 5. Verify custom unequip sound playback
	core.sounds_played = {}
	x_player_armor.unequip(player, "head")
	local unequip_snd = core.sounds_played[#core.sounds_played]
	assert(unequip_snd ~= nil and unequip_snd.name == "mymod_crown_unequip", "Unequip must play custom sound 'mymod_crown_unequip'")

	-- 6. Verify custom hit sound playback on punch
	core.sounds_played = {}
	inv:set_stack("armor", 1, ItemStack("mymod:crown_gold"))
	x_player_armor.set_player_armor(player)
	local pdef = x_player_armor.get_player_def(player)
	assert(pdef.has_reciprocate == true, "Player def must reflect thorns reciprocation")
	assert(pdef.speed == 1.15, "Player def must reflect 1.15 speed modifier")

	local attacker = create_mock_player("custom_attacker")
	x_player_armor.punch(player, attacker, 1.0, {damage_groups = {fleshy = 10}}, {x = 0, y = 0, z = 1}, 10)
	local found_hit_sound = false
	for _, s in ipairs(core.sounds_played) do
		if s.name == "mymod_crown_hit" then
			found_hit_sound = true
			break
		end
	end
	assert(found_hit_sound == true, "Punch must trigger custom hit sound 'mymod_crown_hit'")

	-- 7. Verify custom break sound playback on durability wear
	core.sounds_played = {}
	x_player_armor.damage(player, 1, inv:get_stack("armor", 1), 200000)
	local found_break_sound = false
	for _, s in ipairs(core.sounds_played) do
		if s.name == "mymod_crown_break" then
			found_break_sound = true
			break
		end
	end
	assert(found_break_sound == true, "Armor breaking must trigger custom break sound 'mymod_crown_break'")

	-- Cleanup
	x_player_armor.visuals.clear_all("custom_armor_hero")
end)

test("Skin Mods Integration & 64x64 Format 1.8 3D Preview", function()
	-- 1. Test format detection
	assert(x_player_armor.skins.detect_texture_format("character_18.png") == "1.8", "Texture with _18 suffix must be detected as 1.8")
	assert(x_player_armor.skins.detect_texture_format("character.png") == "1.0", "Default character.png must be detected as 1.0")
	assert(x_player_armor.skins.detect_texture_format("custom_skin_1.8.png") == "1.8", "Texture with 1.8 in name must be detected as 1.8")

	-- 2. Test standard 1.0 player skin resolution
	local player10 = create_mock_player("skin_hero_10")
	local res10 = x_player_armor.skins.resolve_player_skin(player10)
	assert(res10.format == "1.0", "Default player must resolve to Format 1.0")
	assert(res10.body10 == "x_player_armor_character.png", "Body10 must receive default skin")
	assert(res10.body18 == "blank.png", "Body18 must be blank.png for 1.0 skin")

	-- 3. Test skinsdb 1.8 player skin resolution
	local player18 = create_mock_player("skin_hero_18")
	x_player_armor.inventory.init_player_inventory(player18)
	local _, inv = x_player_armor.get_valid_player(player18)
	inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))

	-- Mock skinsdb API
	local mock_skin = {
		get_texture = function() return "skinsdb_skin_valkyrie.png" end,
		get_meta = function(self, key)
			if key == "format" then return "1.8" end
			return nil
		end,
	}
	rawset(_G, "skins", {
		get_player_skin = function(p)
			if p:get_player_name() == "skin_hero_18" then
				return mock_skin
			end
			return nil
		end,
	})

	local res18 = x_player_armor.skins.resolve_player_skin(player18)
	assert(res18.format == "1.8", "Player must resolve to Format 1.8 from skinsdb")
	assert(res18.body10 == "blank.png", "Body10 must be blank.png for 1.8 skin")
	assert(res18.body18 == "skinsdb_skin_valkyrie.png", "Body18 must receive 64x64 skin")

	-- Verify formspec preview contains Body10 as blank and Body18 as valkyrie skin
	local fs18 = x_player_armor.ui.get_formspec(player18)
	assert(fs18:find("blank.png,skinsdb_skin_valkyrie.png,x_player_armor_diamond.png,"), "Formspec must route 1.8 skin to Body18 and keep Body10 blank")

	-- 4. Test clothing mod overlay compositing
	rawset(_G, "clothing", {
		player_textures = {
			skin_hero_18 = {
				jacket = "clothing_jacket_blue.png",
				pants = "clothing_pants_dark.png",
				cape = "clothing_cape.png", -- capes excluded from skin texture
			},
		},
	})

	local res_clothing = x_player_armor.skins.resolve_player_skin(player18)
	assert(res_clothing.body18:find("skinsdb_skin_valkyrie.png%^clothing_"), "Clothing overlays must be composited onto active skin")
	assert(res_clothing.body18:find("clothing_jacket_blue.png"), "Jacket overlay must be present")
	assert(res_clothing.body18:find("clothing_pants_dark.png"), "Pants overlay must be present")
	assert(not res_clothing.body18:find("clothing_cape.png"), "Cape must not be composited into body skin overlay")

	-- 5. Test armor stand mannequin 9-slot properties
	local stand_pos = {x = 100, y = 20, z = 100}
	core.set_node(stand_pos, {name = "x_player_armor:stand", param2 = 0})
	local meta = core.get_meta(stand_pos)
	local stand_inv = meta:get_inventory()
	stand_inv:set_size("armor", 6)
	stand_inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	x_player_armor.stand.update_stand_entity(stand_pos)

	-- Find the spawned stand entity
	local objs = core.get_objects_inside_radius(stand_pos, 0.8)
	local found_stand_ent = false
	for _, obj in ipairs(objs) do
		local luaent = obj:get_luaentity()
		if luaent and luaent.name == "x_player_armor:stand_entity" then
			found_stand_ent = true
			local props = obj:get_properties()
			assert(#props.textures == 9, "Stand entity properties must contain 9 texture slots")
			assert(props.textures[1] == "blank.png", "Stand entity Slot 0 (Body10) must be blank.png")
			assert(props.textures[2] == "blank.png", "Stand entity Slot 1 (Body18) must be blank.png")
			assert(props.textures[3] == "x_player_armor_diamond.png", "Stand entity Slot 2 (Head) must receive helmet texture")
			break
		end
	end
	assert(found_stand_ent == true, "Stand entity must be spawned and verified")

	-- Cleanup mocks
	rawset(_G, "skins", nil)
	rawset(_G, "clothing", nil)
end)

test("Armor Stand & 3D Preview: 9-Slot Alignment, Shield Isolation & Wield Item", function()
	local stand_pos = {x = 105, y = 20, z = 105}
	core.set_node(stand_pos, {name = "x_player_armor:stand", param2 = 0})
	local meta = core.get_meta(stand_pos)
	local stand_inv = meta:get_inventory()
	stand_inv:set_size("armor", 6)

	-- Register mock tool for wielditem testing
	core.register_tool("default:sword_diamond", {
		description = "Diamond Sword",
		inventory_image = "default_tool_diamondsword.png",
	})

	-- 1. Full loadout with standard diamond shield and diamond sword
	stand_inv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	stand_inv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_diamond"))
	stand_inv:set_stack("armor", 3, ItemStack("x_player_armor:leggings_diamond"))
	stand_inv:set_stack("armor", 4, ItemStack("x_player_armor:boots_diamond"))
	stand_inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_diamond"))
	stand_inv:set_stack("armor", 6, ItemStack("default:sword_diamond"))
	x_player_armor.stand.update_stand_entity(stand_pos)

	local objs = core.get_objects_inside_radius(stand_pos, 0.8)
	local found = false
	for _, obj in ipairs(objs) do
		local luaent = obj:get_luaentity()
		if luaent and luaent.name == "x_player_armor:stand_entity" then
			found = true
			local props = obj:get_properties()
			assert(#props.textures == 9, "Must have exactly 9 texture slots")
			assert(props.textures[1] == "blank.png", "Slot 1 (Body10) must be blank.png")
			assert(props.textures[2] == "blank.png", "Slot 2 (Body18) must be blank.png")
			assert(props.textures[3]:find("diamond"), "Slot 3 (Head) must have diamond helmet texture")
			assert(props.textures[4]:find("diamond"), "Slot 4 (Torso) must have diamond chestplate texture")
			assert(props.textures[5]:find("diamond"), "Slot 5 (Legs) must have diamond leggings texture")
			assert(props.textures[6]:find("diamond"), "Slot 6 (Feet) must have diamond boots texture")
			assert(props.textures[7] == "x_player_armor_diamond.png", "Slot 7 (Shield_Standard) must have standard diamond shield texture")
			assert(props.textures[8] == "blank.png", "Slot 8 (Shield_Tower) must be blank.png when standard shield is equipped")
			assert(props.textures[9] == "default_tool_diamondsword.png", "Slot 9 (Wielditem) must show sword texture")
			break
		end
	end
	assert(found, "Stand entity must be present")

	-- 2. Tower shield loadout: verify standard shield becomes blank and tower shield is populated
	stand_inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_enhanced_cactus"))
	x_player_armor.stand.update_stand_entity(stand_pos)

	for _, obj in ipairs(objs) do
		local luaent = obj:get_luaentity()
		if luaent and luaent.name == "x_player_armor:stand_entity" then
			local props = obj:get_properties()
			assert(props.textures[7] == "blank.png", "Slot 7 (Shield_Standard) must be blank.png when tower shield is equipped")
			assert(props.textures[8]:find("cactus"), "Slot 8 (Shield_Tower) must receive tower shield texture")
			assert(props.textures[9] == "default_tool_diamondsword.png", "Slot 9 (Wielditem) must still render weapon")
			break
		end
	end

	-- 3. No shield loadout: verify both shield slots become blank.png
	stand_inv:set_stack("armor", 5, ItemStack(""))
	x_player_armor.stand.update_stand_entity(stand_pos)

	for _, obj in ipairs(objs) do
		local luaent = obj:get_luaentity()
		if luaent and luaent.name == "x_player_armor:stand_entity" then
			local props = obj:get_properties()
			assert(props.textures[7] == "blank.png", "Slot 7 (Shield_Standard) must be blank.png when unequipped")
			assert(props.textures[8] == "blank.png", "Slot 8 (Shield_Tower) must be blank.png when unequipped")
			break
		end
	end

	-- 4. Verify glTF preview model structure directly from disk
	local modpath = core.get_modpath("x_player_armor")
	local f = io.open(modpath .. "/models/x_player_armor_preview.glb", "rb")
	assert(f, "x_player_armor_preview.glb must exist")
	local header = f:read(20)
	f:close()
	assert(#header == 20, "GLB header must be at least 20 bytes")
	local magic = header:sub(1, 4)
	assert(magic == "glTF", "GLB magic header must be glTF")
end)

test("Legacy 3d_armor Dynamic Runtime Override & Technic Armor Ingestion", function()
	-- 1. Setup mock legacy 3d_armor environment prior to takeover
	local legacy_globalstep_called = false
	local legacy_hpchange_called = false
	local other_mod_step_called = false

	-- Create functions with debug source simulation
	-- In Lua, functions created in files have debug info matching that file.
	-- We can create mock functions loaded from string with chunkname.
	local legacy_step_fn = loadstring("return function() legacy_step_hit = true end", "@/mods/3d_armor/3d_armor/init.lua")()
	local legacy_join_fn = loadstring("return function(player) end", "@/mods/3d_armor/3d_armor/init.lua")()
	local legacy_hp_fn = loadstring("return function(player, hp) legacy_hp_hit = true end", "@/mods/3d_armor/3d_armor/init.lua")()
	local other_step_fn = loadstring("return function() other_step_hit = true end", "@/mods/my_custom_mod/init.lua")()

	table.insert(core.registered_globalsteps, legacy_step_fn)
	table.insert(core.registered_globalsteps, other_step_fn)
	table.insert(core.registered_on_joinplayers, legacy_join_fn)
	table.insert(core.registered_on_player_hpchanges, {func = legacy_hp_fn, run_at_every_calculation = true})

	-- Mock legacy 3d_armor global table
	local mock_legacy_armor = {
		version = "0.4.13",
		_is_x_player_armor = nil,
		registered_armors = {
			["technic_armor:helmet_lead"] = {
				description = "Lead Helmet",
				groups = {armor_head = 8, armor_radiation = 80, armor_use = 500},
				armor_groups = {fleshy = 8},
			},
		},
		registered_callbacks = {
			on_equip = {
				loadstring("return function(p, i, s) end", "@/mods/3rd_party/init.lua")(),
			},
		},
	}
	rawset(_G, "armor", mock_legacy_armor)

	-- Mock 3rd-party armor item registered directly in core.registered_tools (e.g. technic shield)
	core.registered_tools["technic_armor:shield_lead"] = {
		description = "Lead Shield",
		groups = {armor_shield = 10, shield = 1, armor_radiation = 50, armor_uses = 600},
	}

	-- Mock duplicate sfinv page from 3d_armor_sfinv
	local sfinv_api = x_player_armor.get_mod_api("sfinv")
	if sfinv_api then
		sfinv_api.pages["3d_armor:armor"] = {title = "Legacy Armor"}
		sfinv_api.pages_unordered = sfinv_api.pages_unordered or {}
		table.insert(sfinv_api.pages_unordered, {name = "3d_armor:armor", title = "Legacy Armor"})
	end

	-- 2. Verify legacy callback detection
	assert(x_player_armor.override.is_legacy_callback(legacy_step_fn) == true, "Must detect legacy 3d_armor callback")
	assert(x_player_armor.override.is_legacy_callback(other_step_fn) == false, "Must not flag 3rd-party mod callback")

	-- 3. Execute takeover
	x_player_armor.override.takeover_legacy_armor()

	-- Re-run compat.armor initialization to ensure _G.armor is modern
	dofile(core.get_modpath("x_player_armor") .. "/modules/compat/armor.lua")

	-- 4. Verify callbacks neutralization in core.registered_*
	assert(core.registered_globalsteps[#core.registered_globalsteps - 1] ~= legacy_step_fn, "Legacy step function must be replaced")
	assert(core.registered_globalsteps[#core.registered_globalsteps] == other_step_fn, "3rd-party step function must be preserved")

	-- Call the neutralized slot to verify it is a safe no-op
	core.registered_globalsteps[#core.registered_globalsteps - 1]()
	assert(legacy_globalstep_called == false, "Neutralized function must not trigger legacy code")

	-- Verify hpchange neutralization
	local hp_entry = core.registered_on_player_hpchanges[#core.registered_on_player_hpchanges]
	assert(hp_entry.func ~= legacy_hp_fn, "Legacy hpchange function must be neutralized")
	hp_entry.func()
	assert(legacy_hpchange_called == false, "Neutralized hpchange must not trigger legacy code")

	-- 5. Verify armor items ingestion into x_player_armor
	assert(x_player_armor.registered_armors["technic_armor:helmet_lead"] ~= nil, "technic_armor:helmet_lead must be ingested")
	local helm_def = x_player_armor.registered_armors["technic_armor:helmet_lead"]
	assert(helm_def.element == "head", "Lead helmet element must be head")
	assert(helm_def.groups.armor_head == 8, "Lead helmet defense level must be 8")

	assert(x_player_armor.registered_armors["technic_armor:shield_lead"] ~= nil, "technic_armor:shield_lead must be ingested")
	local shield_def = x_player_armor.registered_armors["technic_armor:shield_lead"]
	assert(shield_def.element == "shield", "Lead shield element must be shield")
	assert(shield_def.groups.armor_shield == 10, "Lead shield level must be 10")

	-- 6. Verify duplicate sfinv tab suppression
	if sfinv_api then
		assert(sfinv_api.pages["3d_armor:armor"] == nil, "sfinv 3d_armor:armor page must be deleted")
		local found_in_unordered = false
		for _, page in ipairs(sfinv_api.pages_unordered) do
			if page.name == "3d_armor:armor" then
				found_in_unordered = true
				break
			end
		end
		assert(found_in_unordered == false, "sfinv 3d_armor:armor must be removed from pages_unordered")
	end

	-- 7. Verify _G.armor is now modern x_player_armor compat table
	assert(_G.armor ~= nil, "Global armor table must exist")
	assert(_G.armor._is_x_player_armor == true, "Global armor table must be x_player_armor compat")

	-- 8. Verify clean player model restoration with x_player_api priority
	local test_player = create_mock_player("model_test_user")
	local x_api_called_model = nil
	local p_api_called_model = nil

	-- Mock x_player_api with 3d_armor model currently set
	rawset(_G, "x_player_api", {
		get_model_name = function(p) return "3d_armor_character.b3d" end,
		get_default_model = function() return "character" end,
		set_model = function(p, model) x_api_called_model = model end,
	})
	rawset(_G, "player_api", {
		get_model = function(p) return "3d_armor_character.b3d" end,
		set_model = function(p, model) p_api_called_model = model end,
	})

	-- Invoke the latest registered joinplayer callback (which restores clean model)
	local join_fn = core.registered_on_joinplayers[#core.registered_on_joinplayers]
	join_fn(test_player)

	assert(x_api_called_model == "character", "x_player_api.set_model must be prioritized and reset model to clean default")
	assert(p_api_called_model == nil, "Standard player_api must not be called when x_player_api handles it")

	-- Clean up mocks
	core.registered_tools["technic_armor:shield_lead"] = nil
	x_player_armor.registered_armors["technic_armor:helmet_lead"] = nil
	x_player_armor.registered_armors["technic_armor:shield_lead"] = nil
end)

test("Legacy 3D Armor & Shields De-duplication, Registration Override & Recipe Cleanup", function()
	-- 1. Setup simulated duplicate legacy registrations in core registries
	core.registered_tools["3d_armor:helmet_diamond"] = {
		description = "Legacy Diamond Helmet",
		groups = {armor_head = 1, armor_heal = 12, armor_use = 200},
	}
	core.registered_items["3d_armor:helmet_diamond"] = core.registered_tools["3d_armor:helmet_diamond"]

	core.registered_tools["3d_armor:chestplate_wood"] = {
		description = "Legacy Wood Chestplate",
		groups = {armor_torso = 1, armor_heal = 0, armor_use = 2000},
	}
	core.registered_items["3d_armor:chestplate_wood"] = core.registered_tools["3d_armor:chestplate_wood"]

	core.registered_tools["shields:shield_diamond"] = {
		description = "Legacy Diamond Shield",
		groups = {armor_shield = 1, shield = 1, armor_heal = 12, armor_use = 200},
	}
	core.registered_items["shields:shield_diamond"] = core.registered_tools["shields:shield_diamond"]

	core.registered_tools["shields:shield_enhanced_wood"] = {
		description = "Legacy Enhanced Wood Shield",
		groups = {armor_shield = 1, shield = 1, armor_use = 2000},
	}
	core.registered_items["shields:shield_enhanced_wood"] = core.registered_tools["shields:shield_enhanced_wood"]

	core.registered_nodes["3d_armor_stand:armor_stand"] = {
		description = "Legacy Armor Stand",
	}
	core.registered_items["3d_armor_stand:armor_stand"] = core.registered_nodes["3d_armor_stand:armor_stand"]

	core.registered_items["adminshield"] = {
		description = "Legacy Admin Shield",
	}

	-- 2. Setup duplicate craft recipes
	core.register_craft({output = "3d_armor:helmet_diamond", recipe = {{"default:diamond"}}})
	core.register_craft({output = "shields:shield_diamond", recipe = {{"default:diamond"}}})
	core.register_craft({output = "3d_armor_stand:armor_stand", recipe = {{"group:fence"}}})

	-- Also register a 3rd party armor item and craft (must be preserved)
	core.registered_tools["technic_armor:helmet_silver"] = {
		description = "Silver Helmet",
		groups = {armor_head = 6, armor_radiation = 50, armor_use = 400},
	}
	core.registered_items["technic_armor:helmet_silver"] = core.registered_tools["technic_armor:helmet_silver"]
	core.register_craft({output = "technic_armor:helmet_silver", recipe = {{"technic:silver_ingot"}}})

	-- 3. Execute takeover and legacy armor cleanup
	x_player_armor.override.takeover_legacy_armor()

	-- 4. Verify duplicate legacy armors are unregistered and removed from registries
	assert(core.registered_tools["3d_armor:helmet_diamond"] == nil, "3d_armor:helmet_diamond must be unregistered from registered_tools")
	assert(core.registered_items["3d_armor:helmet_diamond"] == nil, "3d_armor:helmet_diamond must be unregistered from registered_items")
	assert(x_player_armor.registered_armors["3d_armor:helmet_diamond"] == nil, "3d_armor:helmet_diamond must not be ingested into registered_armors")
	assert(core.registered_aliases["3d_armor:helmet_diamond"] == "x_player_armor:helmet_diamond", "Alias must point to x_player_armor:helmet_diamond")

	assert(core.registered_tools["3d_armor:chestplate_wood"] == nil, "3d_armor:chestplate_wood must be unregistered from registered_tools")
	assert(core.registered_items["3d_armor:chestplate_wood"] == nil, "3d_armor:chestplate_wood must be unregistered from registered_items")
	assert(x_player_armor.registered_armors["3d_armor:chestplate_wood"] == nil, "3d_armor:chestplate_wood must not be ingested into registered_armors")
	assert(core.registered_aliases["3d_armor:chestplate_wood"] == "x_player_armor:chestplate_wood", "Alias must point to x_player_armor:chestplate_wood")

	assert(core.registered_tools["shields:shield_diamond"] == nil, "shields:shield_diamond must be unregistered from registered_tools")
	assert(core.registered_items["shields:shield_diamond"] == nil, "shields:shield_diamond must be unregistered from registered_items")
	assert(x_player_armor.registered_armors["shields:shield_diamond"] == nil, "shields:shield_diamond must not be ingested into registered_armors")
	assert(core.registered_aliases["shields:shield_diamond"] == "x_player_armor:shield_diamond", "Alias must point to x_player_armor:shield_diamond")

	assert(core.registered_tools["shields:shield_enhanced_wood"] == nil, "shields:shield_enhanced_wood must be unregistered")
	assert(core.registered_aliases["shields:shield_enhanced_wood"] == "x_player_armor:shield_enhanced_wood", "Alias must point to x_player_armor:shield_enhanced_wood")

	assert(core.registered_nodes["3d_armor_stand:armor_stand"] == nil, "3d_armor_stand:armor_stand must be unregistered from registered_nodes")
	assert(core.registered_aliases["3d_armor_stand:armor_stand"] == "x_player_armor:stand", "Stand alias must point to x_player_armor:stand")
	assert(core.registered_aliases["adminshield"] == "x_player_armor:shield_admin", "adminshield alias must point to x_player_armor:shield_admin")

	-- 5. Verify legacy crafting recipes were erased
	for _, c in ipairs(core.registered_crafts) do
		assert(c.output ~= "3d_armor:helmet_diamond", "Craft output for 3d_armor:helmet_diamond must be cleared")
		assert(c.output ~= "shields:shield_diamond", "Craft output for shields:shield_diamond must be cleared")
		assert(c.output ~= "3d_armor_stand:armor_stand", "Craft output for 3d_armor_stand:armor_stand must be cleared")
	end

	-- 6. Verify 3rd-party non-duplicate armor is preserved and ingested
	assert(x_player_armor.registered_armors["technic_armor:helmet_silver"] ~= nil, "technic_armor:helmet_silver must be ingested")
	assert(core.registered_tools["technic_armor:helmet_silver"] ~= nil, "technic_armor:helmet_silver must remain in registered_tools")
	local silver_craft_found = false
	for _, c in ipairs(core.registered_crafts) do
		if c.output == "technic_armor:helmet_silver" then
			silver_craft_found = true
			break
		end
	end
	assert(silver_craft_found == true, "3rd-party craft recipe must be preserved")

	-- 7. Test late registration of superseded item via armor shim
	_G.armor.register_armor(":3d_armor:helmet_gold", {
		description = "Late Gold Helmet",
		groups = {armor_head = 1, armor_heal = 6, armor_use = 300},
	})
	assert(core.registered_tools["3d_armor:helmet_gold"] == nil, "Late registration of 3d_armor:helmet_gold must NOT create duplicate tool")
	assert(x_player_armor.registered_armors["3d_armor:helmet_gold"] == nil, "Late registration must NOT pollute registered_armors")
	assert(core.registered_aliases["3d_armor:helmet_gold"] == "x_player_armor:helmet_gold", "Late registration must ensure alias to modern armor")

	-- 8. Test late registration of 3rd party armor via armor shim with colon prefix (e.g. armor_expanded)
	local registered_tool_passed_name = nil
	local orig_register_tool = core.register_tool
	core.register_tool = function(tname, tdef)
		registered_tool_passed_name = tname
		return orig_register_tool(tname, tdef)
	end

	_G.armor.register_armor(":armor_expanded:helmet_leather", {
		description = "Leather Cap",
		inventory_image = "armor_expanded_inv_helmet_leather.png",
		groups = {armor_head = 1, armor_heal = 0, armor_use = 800, flammable = 1},
		armor_groups = {fleshy = 7},
		damage_groups = {cracky = 3, snappy = 2, choppy = 2, crumbly = 2, level = 1},
	})
	assert(registered_tool_passed_name == ":armor_expanded:helmet_leather", "core.register_tool must receive ':' prefix for sub-mods")
	assert(x_player_armor.registered_armors["armor_expanded:helmet_leather"] ~= nil, "armor_expanded:helmet_leather must be registered")
	assert(core.registered_tools["armor_expanded:helmet_leather"] ~= nil, "armor_expanded:helmet_leather must be in registered_tools")
	assert(x_player_armor.registered_armors["armor_expanded:helmet_leather"].texture == "armor_expanded_helmet_leather.png", "Texture fallback must be populated from item name")
	core.register_tool = orig_register_tool

	_G.armor.register_armor("mymod:helmet_ruby", {
		description = "Ruby Helmet",
		groups = {armor_head = 15, armor_use = 2000},
	})
	assert(x_player_armor.registered_armors["mymod:helmet_ruby"] ~= nil, "3rd-party ruby helmet must be registered")

	-- 9. Test idempotency of subsequent takeover passes (e.g. core.register_on_mods_loaded)
	local clear_craft_calls = 0
	local orig_clear_craft = core.clear_craft
	core.clear_craft = function(recipe)
		clear_craft_calls = clear_craft_calls + 1
		return orig_clear_craft(recipe)
	end
	x_player_armor.override.takeover_legacy_armor()
	assert(clear_craft_calls == 0, "Second takeover pass must not invoke clear_craft when no recipes exist")
	core.clear_craft = orig_clear_craft

	-- Clean up mocks
	core.registered_tools["technic_armor:helmet_silver"] = nil
	core.registered_items["technic_armor:helmet_silver"] = nil
	x_player_armor.registered_armors["technic_armor:helmet_silver"] = nil
	core.registered_tools["mymod:helmet_ruby"] = nil
	core.registered_items["mymod:helmet_ruby"] = nil
	x_player_armor.registered_armors["mymod:helmet_ruby"] = nil
	core.registered_tools["armor_expanded:helmet_leather"] = nil
	core.registered_items["armor_expanded:helmet_leather"] = nil
	x_player_armor.registered_armors["armor_expanded:helmet_leather"] = nil
end)

test("Shield Block Event Pipeline & Projectile Deflection Callbacks (register_on_block)", function()
	local player = create_mock_player("block_cb_hero")
	local attacker = create_mock_player("block_cb_attacker")
	x_player_armor.inventory.init_player_inventory(player)
	local _, inv = x_player_armor.get_valid_player(player)

	player.look_dir = {x = 0, y = 0, z = 1}
	player.controls = {RMB = true}

	-- Equip Steel Shield in slot 5
	inv:set_stack("armor", 5, ItemStack("x_player_armor:shield_steel 1 0"))

	local block_calls = 0
	local last_blocked_damage = 0
	local last_shield_item = nil
	local last_attacker = nil

	local unregister_cb = function(player_ref, hitter, damage, shield_stack)
		block_calls = block_calls + 1
		last_blocked_damage = damage
		last_shield_item = shield_stack and shield_stack:get_name()
		last_attacker = hitter
	end
	x_player_armor.register_on_block(unregister_cb)

	-- 1. Test punch block callback
	x_player_armor.combat.handle_punch(player, attacker, 1.0, {}, {x = 0, y = 0, z = -1}, 20)

	assert(block_calls == 1, "register_on_block callback must be triggered on punch block")
	assert(last_blocked_damage == 20, "Blocked damage passed to callback must be 20")
	assert(last_shield_item == "x_player_armor:shield_steel", "Shield stack passed to callback must be steel shield")
	assert(last_attacker == attacker, "Attacker reference passed to callback must match attacker")

	-- 2. Test projectile deflection callback
	local mock_proj = {
		valid = true,
		is_valid = function(self) return self.valid end,
		get_velocity = function(self) return {x = 0, y = -1, z = -20} end,
		set_velocity = function(self, v) end,
		set_acceleration = function(self, a) end,
		set_rotation = function(self, r) end,
		get_pos = function(self) return {x = 0, y = 10, z = 2} end,
		set_pos = function(self, p) end,
	}

	local deflected = x_player_armor.try_deflect_projectile(player, mock_proj, {x = 0, y = 10, z = 0.5}, {x = 0, y = 0, z = -1})
	assert(deflected == true, "Projectile must be deflected")
	assert(block_calls == 2, "register_on_block callback must be triggered on projectile deflection")
	assert(last_blocked_damage == 0, "Projectile deflection damage passed to callback should be 0")
	assert(last_attacker == mock_proj, "Projectile object passed to callback must match projectile")

	-- Cleanup
	for i = #x_player_armor.callbacks.on_block, 1, -1 do
		if x_player_armor.callbacks.on_block[i] == unregister_cb then
			table.remove(x_player_armor.callbacks.on_block, i)
		end
	end
end)

test("Armor Stand on_equip and on_take Lifecycle Callbacks", function()
	local player = create_mock_player("stand_cb_hero")
	x_player_armor.inventory.init_player_inventory(player)
	local pos = {x = 55, y = 10, z = 55}
	core.set_node(pos, {name = "x_player_armor:stand"})
	local meta = core.get_meta(pos)
	meta:set_string("owner", "stand_cb_hero")
	local sinv = meta:get_inventory()
	sinv:set_size("armor", 5)

	local equip_events = {}
	local take_events = {}

	local on_equip_cb = function(p, slot, stack, plr)
		table.insert(equip_events, {pos = p, slot = slot, item = stack:get_name(), player = plr})
	end
	local on_take_cb = function(p, slot, stack, plr)
		table.insert(take_events, {pos = p, slot = slot, item = stack:get_name(), player = plr})
	end

	x_player_armor.stand.register_on_equip(on_equip_cb)
	x_player_armor.stand.register_on_take(on_take_cb)

	-- Place steel helmet in stand slot 1
	sinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_steel"))
	sinv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_steel"))

	-- 1. Test take_all_armor dispatches on_take for each non-empty slot
	local take_res = x_player_armor.stand.take_all_armor(pos, player)
	assert(take_res == true, "take_all_armor must return true")
	assert(#take_events == 2, "take_all_armor must trigger 2 on_take callbacks for 2 armor pieces")
	assert(take_events[1].slot == 1 and take_events[1].item == "x_player_armor:helmet_steel")
	assert(take_events[2].slot == 2 and take_events[2].item == "x_player_armor:chestplate_steel")

	-- 2. Test node definition callbacks on_metadata_inventory_put and on_metadata_inventory_take
	local stand_node_def = core.registered_nodes["x_player_armor:stand"]
	assert(stand_node_def ~= nil, "x_player_armor:stand node def must exist")

	-- Simulate putting diamond boots into slot 4
	local boot_stack = ItemStack("x_player_armor:boots_diamond")
	sinv:set_stack("armor", 4, boot_stack)
	stand_node_def.on_metadata_inventory_put(pos, "armor", 4, boot_stack, player)

	assert(#equip_events == 1, "on_metadata_inventory_put must trigger on_equip callback")
	assert(equip_events[1].slot == 4)
	assert(equip_events[1].item == "x_player_armor:boots_diamond")

	-- Simulate taking diamond boots from slot 4
	sinv:set_stack("armor", 4, ItemStack(""))
	stand_node_def.on_metadata_inventory_take(pos, "armor", 4, boot_stack, player)

	assert(#take_events == 3, "on_metadata_inventory_take must trigger on_take callback")
	assert(take_events[3].slot == 4)
	assert(take_events[3].item == "x_player_armor:boots_diamond")

	-- Cleanup
	for i = #x_player_armor.stand.callbacks.on_equip, 1, -1 do
		if x_player_armor.stand.callbacks.on_equip[i] == on_equip_cb then
			table.remove(x_player_armor.stand.callbacks.on_equip, i)
		end
	end
	for i = #x_player_armor.stand.callbacks.on_take, 1, -1 do
		if x_player_armor.stand.callbacks.on_take[i] == on_take_cb then
			table.remove(x_player_armor.stand.callbacks.on_take, i)
		end
	end
end)

test("Cursed Armor Protection Against Displacement in equip_item and unequip_element", function()
	local player = create_mock_player("cursed_equip_user")
	x_player_armor.inventory.init_player_inventory(player)
	local _, pinv = x_player_armor.get_valid_player(player)

	core.registered_tools["testmod:cursed_chestplate"] = {
		description = "Cursed Chestplate",
		groups = {armor_torso = 15, cursed = 1},
	}
	core.registered_tools["testmod:holy_chestplate"] = {
		description = "Holy Chestplate",
		groups = {armor_torso = 20},
	}

	-- Equip cursed chestplate directly
	pinv:set_stack("armor", 2, ItemStack("testmod:cursed_chestplate"))
	x_player_armor.set_player_armor(player)

	-- 1. Try to unequip torso element programmatically
	local unequip_res = x_player_armor.inventory.unequip_element(player, "torso")
	assert(unequip_res:is_empty() == true, "unequip_element must return empty stack when slot is cursed")
	assert(pinv:get_stack("armor", 2):get_name() == "testmod:cursed_chestplate", "Cursed item must remain equipped")

	-- 2. Try to equip new chestplate over cursed chestplate
	local equip_res = x_player_armor.inventory.equip_item(player, ItemStack("testmod:holy_chestplate"))
	assert(equip_res == nil, "equip_item must return nil when target slot contains cursed item")
	assert(pinv:get_stack("armor", 2):get_name() == "testmod:cursed_chestplate", "Cursed item must not be displaced")

	-- 3. Test non-cursed slot behavior
	pinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_steel"))
	local unequip_head_res = x_player_armor.inventory.unequip_element(player, "head")
	assert(unequip_head_res:get_name() == "x_player_armor:helmet_steel", "unequip_element must return unequipped item for non-cursed armor")
	assert(pinv:get_stack("armor", 1):is_empty(), "Non-cursed item must be unequipped")

	-- Cleanup
	core.registered_tools["testmod:cursed_chestplate"] = nil
	core.registered_tools["testmod:holy_chestplate"] = nil
end)

test("Subsystem Inspection Accessors & Definition Lookups (get_armor_def, items, crafting, force_alias)", function()
	-- 1. get_armor_def lookups
	local diamond_def = x_player_armor.get_armor_def("x_player_armor:helmet_diamond")
	assert(diamond_def ~= nil, "get_armor_def must resolve modern armor item")
	assert(diamond_def.groups and diamond_def.groups.armor_head ~= nil, "Definition must have armor_head group")

	-- Legacy alias resolution
	local legacy_def = x_player_armor.get_armor_def("3d_armor:helmet_diamond")
	assert(legacy_def ~= nil, "get_armor_def must resolve legacy alias name")
	assert(legacy_def.groups and legacy_def.groups.armor_head ~= nil, "Resolved legacy def must have armor_head group")

	-- Invalid lookup returns nil
	assert(x_player_armor.get_armor_def("") == nil, "get_armor_def for empty string must return nil")
	assert(x_player_armor.get_armor_def(nil) == nil, "get_armor_def for nil must return nil")

	-- 2. items subsystem accessors
	local materials = x_player_armor.items.get_materials()
	assert(type(materials) == "table", "get_materials must return a table")
	assert(materials.diamond ~= nil, "materials must contain diamond")
	assert(materials.steel ~= nil, "materials must contain steel")

	local pieces = x_player_armor.items.get_pieces()
	assert(type(pieces) == "table", "get_pieces must return a table")
	assert(pieces.helmet ~= nil, "pieces must contain helmet")
	assert(pieces.shield ~= nil, "pieces must contain shield")

	-- 3. crafting subsystem accessors
	local ingredients = x_player_armor.crafting.get_recipe_ingredients()
	assert(type(ingredients) == "table", "get_recipe_ingredients must return a table")
	assert(ingredients.diamond == "default:diamond", "diamond recipe ingredient must be default:diamond")

	-- 4. utils.force_alias helper
	x_player_armor.utils.force_alias("test_mod:old_item", "test_mod:new_item")
	assert(core.registered_aliases["test_mod:old_item"] == "test_mod:new_item", "force_alias must register alias in core.registered_aliases")
end)

test("Armor Stand Blast Protection and Drop Consistency (on_blast)", function()
	local pos = {x = 80, y = 20, z = 80}
	core.set_node(pos, {name = "x_player_armor:stand"})
	local meta = core.get_meta(pos)
	local sinv = meta:get_inventory()
	sinv:set_size("armor", 5)

	sinv:set_stack("armor", 1, ItemStack("x_player_armor:helmet_diamond"))
	sinv:set_stack("armor", 2, ItemStack("x_player_armor:chestplate_diamond"))
	sinv:set_stack("armor", 5, ItemStack("x_player_armor:shield_diamond"))

	local stand_node_def = core.registered_nodes["x_player_armor:stand"]
	assert(stand_node_def ~= nil and type(stand_node_def.on_blast) == "function", "stand node def must define on_blast")

	local drops = stand_node_def.on_blast(pos, 2.0)
	assert(type(drops) == "table", "on_blast must return a table of drops")
	assert(#drops == 4, "on_blast must return 3 armor items + 1 stand item (4 total), got " .. #drops)

	local found_helm, found_chest, found_shield, found_stand = false, false, false, false
	for _, stack in ipairs(drops) do
		local name = stack:get_name()
		if name == "x_player_armor:helmet_diamond" then found_helm = true
		elseif name == "x_player_armor:chestplate_diamond" then found_chest = true
		elseif name == "x_player_armor:shield_diamond" then found_shield = true
		elseif name == "x_player_armor:stand" then found_stand = true
		end
	end

	assert(found_helm, "drops must include diamond helmet")
	assert(found_chest, "drops must include diamond chestplate")
	assert(found_shield, "drops must include diamond shield")
	assert(found_stand, "drops must include armor stand node")

	-- Node must be removed
	assert(core.get_node(pos).name == "air", "Armor stand node must be removed from map after blast")
end)

test("Modular Visual Attachment to External Entities (attach_armor_to_entity)", function()
	local mock_parent = {
		pos = { x = 10, y = 5, z = 10 },
		props = { mesh = "character.glb" },
		get_pos = function(self) return self.pos end,
		get_properties = function(self) return self.props end,
		is_valid = function(self) return true end,
	}

	local armor_list = {
		"x_player_armor:helmet_diamond",
		"x_player_armor:chestplate_diamond",
		"x_player_armor:leggings_diamond",
		"x_player_armor:boots_diamond",
	}

	local attached = x_player_armor.attach_armor_to_entity(mock_parent, armor_list, "glb")
	assert(type(attached) == "table", "attach_armor_to_entity must return a table of entities")
	assert(#attached > 0, "attach_armor_to_entity must spawn visual pieces for equipped armor items")

	-- Verify modular entities are tagged as corpse attachments
	for _, ent in ipairs(attached) do
		local luaent = ent:get_luaentity()
		assert(luaent ~= nil, "Spawned armor entity must have luaentity table")
		assert(luaent._is_corpse == true, "Corpse armor entity must be flagged _is_corpse")
		assert(luaent._intentional_removal == true, "Corpse armor entity must have _intentional_removal flag")
		ent:remove()
	end
end)

test("Shield Visual Attachment to External Entities (attach_shield_to_entity)", function()
	local mock_glb_parent = {
		pos = { x = 15, y = 5, z = 15 },
		props = { mesh = "character.glb" },
		get_pos = function(self) return self.pos end,
		get_properties = function(self) return self.props end,
		is_valid = function(self) return true end,
	}

	-- 1. GLB shield attachment
	local glb_shield = x_player_armor.attach_shield_to_entity(mock_glb_parent, "x_player_armor:shield_steel", "glb")
	assert(glb_shield ~= nil and glb_shield:is_valid(), "attach_shield_to_entity must return valid shield entity")
	local _, bone_glb, pos_glb, rot_glb = glb_shield:get_attach()
	assert(bone_glb == "Arm_Left", "Shield must be attached to Arm_Left")
	assert(math.abs(pos_glb.x - (-0.8)) < 0.01 and math.abs(pos_glb.y - 5.0) < 0.01 and math.abs(pos_glb.z - (-2.8)) < 0.01,
		"GLB shield position must match x_player_armor forearm offset")
	assert(math.abs(rot_glb.x - 180) < 0.01 and math.abs(rot_glb.y - 45) < 0.01,
		"GLB shield rotation must match x_player_armor forearm rotation")
	local glb_lua = glb_shield:get_luaentity()
	assert(glb_lua ~= nil and glb_lua._is_corpse == true, "Shield entity must have _is_corpse flag")
	glb_shield:remove()

	-- 2. B3D shield attachment
	local mock_b3d_parent = {
		pos = { x = 20, y = 5, z = 20 },
		props = { mesh = "character.b3d" },
		get_pos = function(self) return self.pos end,
		get_properties = function(self) return self.props end,
		is_valid = function(self) return true end,
	}
	local b3d_shield = x_player_armor.attach_shield_to_entity(mock_b3d_parent, "x_player_armor:shield_steel", "b3d")
	assert(b3d_shield ~= nil and b3d_shield:is_valid(), "B3D attach_shield_to_entity must return valid shield entity")
	local _, bone_b3d, pos_b3d, rot_b3d = b3d_shield:get_attach()
	assert(bone_b3d == "Arm_Left", "B3D shield must be attached to Arm_Left")
	assert(math.abs(pos_b3d.x - (-0.8)) < 0.01 and math.abs(pos_b3d.y - 5.0) < 0.01 and math.abs(pos_b3d.z - 2.8) < 0.01,
		"B3D shield position must match x_player_armor forearm offset")
	assert(math.abs(rot_b3d.x - 180) < 0.01 and math.abs(rot_b3d.y - (-45)) < 0.01,
		"B3D shield rotation must match x_player_armor forearm rotation")
	b3d_shield:remove()

	-- 3. Top-level x_player_armor.attach_shield delegates to attach_shield_to_entity when passed an entity
	local top_shield = x_player_armor.attach_shield(mock_glb_parent, "x_player_armor:shield_diamond", "glb")
	assert(top_shield ~= nil and top_shield:is_valid(), "attach_shield must handle external parent entity")
	local _, top_bone = top_shield:get_attach()
	assert(top_bone == "Arm_Left", "Top-level attach_shield must attach to Arm_Left")
	top_shield:remove()
end)

print(string.format("\n=========================================="))
print(string.format("  ALL %d UNIT TESTS PASSED SUCCESSFULLY!  ", passed))
print(string.format("=========================================="))



