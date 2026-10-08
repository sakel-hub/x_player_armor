---@class XPlayerArmorStand
local stand = {
	callbacks = {
		on_equip = {},
		on_take = {},
		on_swap = {},
	},
}

local S = core.get_translator("x_player_armor")
local constants = x_player_armor.constants
local utils = x_player_armor.utils

-- Debounced restoration queue for self-healing when entities are cleared
local pending_restores = {}
local restore_scheduled = false

local function hash_pos(pos)
	if core.hash_node_position then
		return core.hash_node_position(pos)
	end
	return pos.x .. ":" .. pos.y .. ":" .. pos.z
end

---Registers a stand position for deferred rehydration.
---@param pos vector
function stand.schedule_restore(pos)
	local hash = hash_pos(pos)
	pending_restores[hash] = vector.new(pos)
	if not restore_scheduled then
		restore_scheduled = true
		core.after(0.5, function()
			restore_scheduled = false
			local batch = pending_restores
			pending_restores = {}
			for _, p in pairs(batch) do
				local node = core.get_node_or_nil(p)
				if node and (node.name == "x_player_armor:stand" or node.name == "x_player_armor:locked_stand") then
					stand.update_stand_entity(p)
				end
			end
		end)
	end
end

local STAND_ENTITY_OFFSET = vector.new(0, -0.41, 0)
stand.STAND_ENTITY_OFFSET = STAND_ENTITY_OFFSET

-- Visual mannequin entity for armor stands (Single-entity preview mesh)
core.register_entity("x_player_armor:stand_entity", {
	initial_properties = {
		visual = "mesh",
		mesh = constants.MODELS.stand_entity,
		textures = {
			"blank.png",
			"blank.png",
			"blank.png",
			"blank.png",
			"blank.png",
			"blank.png",
			"blank.png",
			"blank.png",
		},
		visual_size = {x = 1, y = 1, z = 1},
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		backface_culling = false,
		shaded = true,
	},
	on_step = nil, -- Zero Lua tick overhead
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
	on_deactivate = function(self, removal)
		if removal and not self._intentional_removal and self._stand_pos then
			stand.schedule_restore(self._stand_pos)
		end
	end,
})

-- Visual entity for stand-mounted shields (Obsolete child entity, retained for backwards compatibility)
core.register_entity("x_player_armor:stand_shield", {
	initial_properties = {
		visual = "mesh",
		mesh = constants.MODELS.shield,
		textures = {"blank.png"},
		visual_size = {x = 1, y = 1, z = 1},
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
	},
	on_step = nil,
	on_activate = function(self)
		-- Obsolete child entity removed in single-mesh preview architecture
		self.object:remove()
	end,
})

---Finds the stand entity at a specific position.
---@param pos vector
---@return ObjectRef? entity
local function get_stand_entity(pos)
	local objs = core.get_objects_inside_radius(pos, 0.8)
	for i = 1, #objs do
		local obj = objs[i]
		local luaent = obj:get_luaentity()
		if luaent and luaent.name == "x_player_armor:stand_entity" then
			return obj
		end
	end
	return nil
end

---Finds the attached shield entity at a specific position.
---@param pos vector
---@return ObjectRef? entity
local function get_stand_shield(pos)
	local objs = core.get_objects_inside_radius(pos, 0.8)
	for i = 1, #objs do
		local obj = objs[i]
		local luaent = obj:get_luaentity()
		if luaent and luaent.name == "x_player_armor:stand_shield" then
			return obj
		end
	end
	return nil
end

---Updates the mannequin textures and attached equipment on the stand entity.
---@param pos vector
local function update_stand_entity(pos)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	if inv:get_size("armor") < 6 then
		inv:set_size("armor", 6)
	end
	local list = inv:get_list("armor")
	if not list then return end

	local node = core.get_node(pos)
	local dir = core.facedir_to_dir(node.param2 or 0)
	local yaw = (core.dir_to_yaw(dir) + math.pi) % (2 * math.pi)

	-- Material array for x_player_armor_preview.glb (8 slots):
	-- 1: Body (blank.png; stand 3D node already has wooden arms built in)
	-- 2: Head (list[1])
	-- 3: Torso (list[2])
	-- 4: Legs (list[3])
	-- 5: Feet (list[4])
	-- 6: Shield_Standard (list[5] if standard shield)
	-- 7: Shield_Tower (list[5] if tower shield)
	-- 8: Wielditem (list[6])

	local body_tex = "blank.png"

	local head_tex = "blank.png"
	if list[1] and not list[1]:is_empty() then
		head_tex = x_player_armor.visuals.get_item_texture(list[1]:get_name()) or "blank.png"
	end

	local torso_tex = "blank.png"
	if list[2] and not list[2]:is_empty() then
		torso_tex = x_player_armor.visuals.get_item_texture(list[2]:get_name()) or "blank.png"
	end

	local legs_tex = "blank.png"
	if list[3] and not list[3]:is_empty() then
		legs_tex = x_player_armor.visuals.get_item_texture(list[3]:get_name()) or "blank.png"
	end

	local feet_tex = "blank.png"
	if list[4] and not list[4]:is_empty() then
		feet_tex = x_player_armor.visuals.get_item_texture(list[4]:get_name()) or "blank.png"
	end

	local shield_std_tex = "blank.png"
	local shield_tower_tex = "blank.png"
	if list[5] and not list[5]:is_empty() then
		local shield_item = list[5]:get_name()
		local s_tex = x_player_armor.visuals.get_item_texture(shield_item)
		if s_tex and s_tex ~= "" then
			local is_tower = core.get_item_group(shield_item, "armor_shield_tower") > 0
				or core.get_item_group(shield_item, "armor_tower_shield") > 0
			if not is_tower then
				local def = core.registered_items[shield_item]
				if def and (def.tower_shield or def.tower) then
					is_tower = true
				end
			end

			if is_tower then
				shield_tower_tex = s_tex
			else
				shield_std_tex = s_tex
			end
		end
	end

	local wield_tex = "blank.png"
	if list[6] and not list[6]:is_empty() then
		wield_tex = x_player_armor.ui.get_item_wield_texture(list[6])
	end

	local textures = {
		body_tex,
		head_tex,
		torso_tex,
		legs_tex,
		feet_tex,
		shield_std_tex,
		shield_tower_tex,
		wield_tex,
	}

	local ent_pos = vector.add(pos, STAND_ENTITY_OFFSET)
	local obj = get_stand_entity(pos)
	if not obj then
		obj = core.add_entity(ent_pos, "x_player_armor:stand_entity")
	else
		obj:set_pos(ent_pos)
	end

	if obj and obj:is_valid() then
		local luaent = obj:get_luaentity()
		if luaent then
			luaent._stand_pos = vector.new(pos)
			luaent._intentional_removal = false
		end
		obj:set_yaw(yaw)
		obj:set_properties({
			textures = textures,
			backface_culling = false,
		})
	end

	-- Clean up obsolete standalone shield entities if present
	local old_shield = get_stand_shield(pos)
	if old_shield and old_shield:is_valid() then
		local sluaent = old_shield:get_luaentity()
		if sluaent then
			sluaent._intentional_removal = true
		end
		old_shield:remove()
	end

	-- Update node infotext
	local owner = meta:get_string("owner")
	local is_locked = (node.name == "x_player_armor:locked_stand")
	local mounted = {}
	for i = 1, 6 do
		local stack = list[i]
		if stack and not stack:is_empty() then
			local def = stack:get_definition()
			local piece_name = (def and (def.short_description or def.description)) or stack:get_name()
			table.insert(mounted, piece_name)
		end
	end

	local infotext
	if is_locked and owner ~= "" then
		if #mounted > 0 then
			infotext = S("Locked Armor Stand (Owned by @1)\nEquipped: @2", owner, table.concat(mounted, ", "))
		else
			infotext = S("Locked Armor Stand (Owned by @1) [Empty]", owner)
		end
	elseif owner ~= "" then
		if #mounted > 0 then
			infotext = S("Armor Stand (Placed by @1)\nEquipped: @2", owner, table.concat(mounted, ", "))
		else
			infotext = S("Armor Stand (Placed by @1) [Empty]", owner)
		end
	else
		if #mounted > 0 then
			infotext = S("Armor Stand\nEquipped: @1", table.concat(mounted, ", "))
		else
			infotext = S("Armor Stand [Empty]")
		end
	end
	meta:set_string("infotext", infotext)
end

local STAND_SLOTS = {
	{
		idx = 0, lua_idx = 1, x = 1.0, y = 2.05,
		icon = "x_player_armor_stand_head.png",
		title = "Helmet Slot", desc = "Place a helmet or headpiece here.",
	},
	{
		idx = 1, lua_idx = 2, x = 2.2, y = 2.05,
		icon = "x_player_armor_stand_torso.png",
		title = "Chestplate Slot", desc = "Place a chestplate or cuirass here.",
	},
	{
		idx = 4, lua_idx = 5, x = 3.4, y = 2.05,
		icon = "x_player_armor_stand_shield.png",
		title = "Shield Slot", desc = "Place a shield here.",
	},
	{
		idx = 2, lua_idx = 3, x = 1.0, y = 3.35,
		icon = "x_player_armor_stand_legs.png",
		title = "Leggings Slot", desc = "Place leggings or greaves here.",
	},
	{
		idx = 3, lua_idx = 4, x = 2.2, y = 3.35,
		icon = "x_player_armor_stand_feet.png",
		title = "Boots Slot", desc = "Place boots here.",
	},
	{
		idx = 5, lua_idx = 6, x = 3.4, y = 3.35,
		icon = "x_player_armor_icon.png",
		title = "Weapon Slot", desc = "Place a weapon, tool, or wielded item here.",
	},
}

local PLAYER_STAND_SLOTS = {
	{
		idx = 0, lua_idx = 1, x = 7.1, y = 2.05,
		icon = "x_player_armor_stand_head.png",
		title = "Helmet Slot", desc = "Equip a helmet or headpiece here for defense.",
	},
	{
		idx = 1, lua_idx = 2, x = 8.3, y = 2.05,
		icon = "x_player_armor_stand_torso.png",
		title = "Chestplate Slot", desc = "Equip a chestplate or body armor here for core protection.",
	},
	{
		idx = 4, lua_idx = 5, x = 9.5, y = 2.05,
		icon = "x_player_armor_stand_shield.png",
		title = "Shield Slot", desc = "Equip a shield here for active frontal damage blocking.",
	},
	{
		idx = 2, lua_idx = 3, x = 7.1, y = 3.35,
		icon = "x_player_armor_stand_legs.png",
		title = "Leggings Slot", desc = "Equip leggings or greaves here for lower-body defense.",
	},
	{
		idx = 3, lua_idx = 4, x = 8.3, y = 3.35,
		icon = "x_player_armor_stand_feet.png",
		title = "Boots Slot", desc = "Equip boots here for foot protection and mobility.",
	},
	{
		idx = 5, lua_idx = 6, x = 9.5, y = 3.35,
		icon = "x_player_armor_icon.png",
		title = "Accessory Slot", desc = "Equip extra armor or an accessory here.",
	},
}

---Checks if a player is authorized to interact with the armor stand.
---@param pos vector Node position
---@param player ObjectRef Player reference
---@param is_locked boolean? Whether the stand is an owner-locked variant
---@return boolean can_interact
local function can_interact(pos, player, is_locked)
	if not player or not player:is_player() then return false end
	local name = player:get_player_name()
	local meta = core.get_meta(pos)
	local owner = meta:get_string("owner")
	local has_bypass = core.check_player_privs(name, {protection_bypass = true})
	if has_bypass then
		return true
	end

	local node = core.get_node(pos)
	local locked = is_locked
	if locked == nil then
		locked = (node.name == "x_player_armor:locked_stand") or (owner ~= "")
	end

	-- Locked armor stands enforce strict ownership
	if locked and owner ~= "" and owner ~= name then
		return false
	end

	-- Unlocked and locked stands both respect general area protection
	if core.is_protected(pos, name) then
		return false
	end
	return true
end
stand.can_interact = can_interact

---Checks whether an item is valid for a given stand slot element.
---@param stack ItemStack
---@param index number (1..6)
---@return boolean is_valid
local function is_valid_stand_item(stack, index)
	if not stack or stack:is_empty() then return false end
	local item_name = stack:get_name()
	local resolved_name = core.registered_aliases[item_name] or item_name
	local def = core.registered_tools[resolved_name] or core.registered_items[resolved_name] or stack:get_definition()

	if index == 6 then
		-- Slot 6 is the weapon/tool/held item slot.
		-- Primary body armor pieces (head, torso, legs, feet) belong in slots 1..4
		-- to prevent shift-clicking from greedily misrouting body armor into the weapon slot.
		if def and def.groups then
			if (def.groups.armor_head or 0) > 0
				or (def.groups.armor_torso or 0) > 0
				or (def.groups.armor_legs or 0) > 0
				or (def.groups.armor_feet or 0) > 0 then
				return false
			end
		end
		return true
	end

	local elem = constants.SLOT_ELEMENTS[index]
	if not elem then return false end
	local group = constants.ELEMENT_GROUPS[elem]
	if not def or not def.groups then return false end
	return (def.groups[group] or 0) > 0
end
stand.is_valid_stand_item = is_valid_stand_item

---Determines the armor slot from vertical and lateral raycast hit location.
---@param pos vector Node coordinates
---@param intersection_point vector? Hit coordinates
---@param node table? Optional node table (retrieved if nil)
---@return number slot (1..6)
local function get_slot_from_intersection(pos, intersection_point, node)
	if not intersection_point then return 1 end
	local rel_y = intersection_point.y - pos.y
	if rel_y >= 0.65 then
		return 1 -- Helmet
	elseif rel_y < -0.20 then
		return 4 -- Boots
	elseif rel_y < 0.15 then
		return 3 -- Leggings
	end

	-- rel_y is in torso/arms zone [0.15, 0.65)
	local n = node or core.get_node(pos)
	local dir = core.facedir_to_dir(n.param2 or 0)
	-- Lateral projection onto stand's right-hand vector R = (dir.z, -dir.x)
	-- lateral > 0 => Stand's right arm (holding weapon)
	-- lateral < 0 => Stand's left arm (holding shield)
	local lateral = (intersection_point.x - pos.x) * dir.z - (intersection_point.z - pos.z) * dir.x
	if lateral > 0.15 then
		return 6 -- Weapon / Tool (Right arm)
	elseif lateral < -0.15 then
		return 5 -- Shield (Left arm)
	else
		return 2 -- Chestplate / Torso (Center)
	end
end
stand.get_slot_from_intersection = get_slot_from_intersection

---Builds the Formspec Version 7 UI for the Armor Stand.
---@param pos vector Node coordinates
---@param player ObjectRef Player viewing the formspec
---@return string formspec
function stand.get_stand_formspec(pos, player)
	local name = player:get_player_name()
	local meta = core.get_meta(pos)
	local owner = meta:get_string("owner")
	local node = core.get_node(pos)
	local is_locked = (node.name == "x_player_armor:locked_stand")
	local stand_inv = meta:get_inventory()
	if stand_inv and stand_inv:get_size("armor") < 6 then
		stand_inv:set_size("armor", 6)
	end
	local player_inv = core.get_inventory({type = "detached", name = name .. "_armor"})

	local title_str
	if is_locked and owner ~= "" then
		title_str = S("LOCKED ARMOR STAND - @1", owner)
	elseif owner ~= "" then
		title_str = S("ARMOR STAND - @1", owner)
	else
		title_str = S("ARMOR STAND")
	end

	local fs = {
		"formspec_version[7]",
		"size[11.6,11.1]",
		"style_type[box;border=false]",
		"style_type[label;font=bold]",
		"style_type[list;size=1.0,1.0;spacing=0.15]",
		"listcolors[#00000069;#5A5A5A;#141318;#10141cf0;#c9d1d9]",
		"box[0,0;11.6,11.1;#0d1117]",

		-- Top Header Card
		"box[0.6,0.4;10.4,0.7;#161b22]",
		string.format("label[0.9,0.78;%s]", core.formspec_escape(title_str)),
		"style[btn_close;bgcolor=#21262d;textcolor=#8b949e;font=bold;border=true;borderwidth=1;bordercolor=#30363d]",
		"style[btn_close:hover;bgcolor=#da3633;textcolor=#ffffff;bordercolor=#f85149]",
		"style[btn_close:pressed;bgcolor=#b62324;textcolor=#ffffff;bordercolor=#da3633]",
		"button_exit[10.42,0.48;0.52,0.54;btn_close;X]",
		"tooltip[btn_close;" .. core.formspec_escape(S("Close")) .. ";#10141cf0;#c9d1d9]",

		-- 1st Column: Stand Mounted Armor Card
		"box[0.6,1.3;4.3,3.9;#161b22]",
		"label[0.9,1.65;" .. core.colorize("#58a6ff", core.formspec_escape(S("STAND ARMOR"))) .. "]",

		-- Center Column: Quick Action Controls
		"box[5.1,1.3;1.4,3.9;#161b22]",
		"style[btn_swap_armor;bgcolor=#172b4d;textcolor=#58a6ff;font=bold;border=true;borderwidth=1;bordercolor=#388bfd]",
		"style[btn_swap_armor:hover;bgcolor=#1f4273;textcolor=#ffffff;bordercolor=#79c0ff]",
		"style[btn_swap_armor:pressed;bgcolor=#0e1c33;textcolor=#388bfd;bordercolor=#1f6feb]",
		"button[5.2,2.05;1.2,1.0;btn_swap_armor;" .. core.formspec_escape(S("Swap")) .. "]",
		"tooltip[btn_swap_armor;" .. core.formspec_escape(S("Swap all equipped armor between player and stand")) .. ";#10141cf0;#c9d1d9]",
		"style[btn_take_all;bgcolor=#21262d;textcolor=#c9d1d9;font=bold;border=true;borderwidth=1;bordercolor=#30363d]",
		"style[btn_take_all:hover;bgcolor=#30363d;textcolor=#ffffff;bordercolor=#8b949e]",
		"style[btn_take_all:pressed;bgcolor=#161b22;textcolor=#8b949e;bordercolor=#484f58]",
		"button[5.2,3.35;1.2,1.0;btn_take_all;" .. core.formspec_escape(S("Take")) .. "]",
		"tooltip[btn_take_all;" .. core.formspec_escape(S("Take all armor from stand into player inventory")) .. ";#10141cf0;#c9d1d9]",

		-- 3rd Column: Player Equipped Armor Card
		"box[6.7,1.3;4.3,3.9;#161b22]",
		"label[7.0,1.65;" .. core.colorize("#58a6ff", core.formspec_escape(S("YOUR ARMOR"))) .. "]",
	}

	-- Stand Slots (6 slots) via shared renderer
	table.insert(fs, x_player_armor.ui.render_slots(
		string.format("nodemeta:%d,%d,%d", pos.x, pos.y, pos.z),
		{1.05, 2.25, 3.45},
		{2.05, 3.35},
		1.0,
		stand_inv,
		STAND_SLOTS
	))

	-- Player Slots (6 slots) via shared renderer
	table.insert(fs, x_player_armor.ui.render_slots(
		string.format("detached:%s_armor", name),
		{7.15, 8.35, 9.55},
		{2.05, 3.35},
		1.0,
		player_inv,
		PLAYER_STAND_SLOTS
	))

	-- Player Inventory & Hotbar Card (Hotbar above 8x3 Main Inventory, without title/labels)
	table.insert(fs, "box[0.6,5.4;10.4,5.3;#161b22]")
	table.insert(fs, x_player_armor.ui.render_player_hotbar(1.275, 5.75, 0.15))
	table.insert(fs, x_player_armor.ui.render_player_inventory(1.275, 7.05))

	-- Shift-click circular listring loop
	table.insert(fs, string.format("listring[nodemeta:%d,%d,%d;armor]", pos.x, pos.y, pos.z))
	table.insert(fs, string.format("listring[detached:%s_armor;armor]", name))
	table.insert(fs, "listring[current_player;main]")
	table.insert(fs, string.format("listring[nodemeta:%d,%d,%d;armor]", pos.x, pos.y, pos.z))

	return table.concat(fs, "")
end

---Swaps all equipped armor pieces and held weapon between player and stand.
---@param pos vector Stand coordinates
---@param player ObjectRef Player reference
---@param is_locked boolean? Whether the stand is owner-locked
---@return boolean success
function stand.swap_armor(pos, player, is_locked)
	if not can_interact(pos, player, is_locked) then
		core.chat_send_player(player:get_player_name(), S("You do not have permission to access this armor stand."))
		return false
	end
	local name = player:get_player_name()
	local pinv = core.get_inventory({type = "detached", name = name .. "_armor"})
	if not pinv then return false end
	local meta = core.get_meta(pos)
	local sinv = meta:get_inventory()
	if not sinv then return false end
	if sinv:get_size("armor") < 6 then
		sinv:set_size("armor", 6)
	end

	-- Check for cursed armor in player inventory
	for idx = 1, 5 do
		local p_stack = pinv:get_stack("armor", idx)
		local def = p_stack:get_definition()
		if def and def.groups and (def.groups.cursed == 1 or def.groups.armor_cursed == 1) then
			core.chat_send_player(name, S("Cannot swap armor: @1 is cursed!", def.short_description or def.description or p_stack:get_name()))
			return false
		end
	end
	local p_wield = player:get_wielded_item()
	if p_wield and not p_wield:is_empty() then
		local w_def = p_wield:get_definition()
		if w_def and w_def.groups and (w_def.groups.cursed == 1 or w_def.groups.armor_cursed == 1) then
			core.chat_send_player(name, S("Cannot swap armor: @1 is cursed!", w_def.short_description or w_def.description or p_wield:get_name()))
			return false
		end
	end

	-- Check if at least one side has an item to swap
	local has_items = false
	for idx = 1, 5 do
		if not pinv:get_stack("armor", idx):is_empty() or not sinv:get_stack("armor", idx):is_empty() then
			has_items = true
			break
		end
	end
	local s_wield = sinv:get_stack("armor", 6)
	if not has_items and ((p_wield and not p_wield:is_empty()) or (s_wield and not s_wield:is_empty())) then
		has_items = true
	end
	if not has_items then
		return false
	end

	-- Atomically swap armor slots 1..5
	for idx = 1, 5 do
		local p_stack = pinv:get_stack("armor", idx)
		local s_stack = sinv:get_stack("armor", idx)
		pinv:set_stack("armor", idx, s_stack)
		sinv:set_stack("armor", idx, p_stack)
	end

	-- Swap weapon slot 6 with player wielded item
	sinv:set_stack("armor", 6, p_wield)
	player:set_wielded_item(s_wield)

	-- Update player armor state, stats, visuals and active effects
	x_player_armor.inventory.save_inventory(player, pinv)
	x_player_armor.set_player_armor(player)
	x_player_armor.update_player_visuals(player)
	x_player_armor.run_callbacks("on_update", player)
	x_player_armor.ui.refresh_player_formspec(player)

	-- Update in-world mannequin visual
	update_stand_entity(pos)

	-- Sound feedback
	local sounds = constants.SOUNDS
	if sounds and sounds.equip then
		core.sound_play(sounds.equip, {pos = pos, gain = 0.8, max_hear_distance = 16.0})
	end

	stand.run_callbacks("on_swap", pos, player)
	return true
end

---Performs analytical ray vs AABB intersection for stand selection box.
---@param origin vector
---@param dir vector
---@param bmin vector
---@param bmax vector
---@return vector? intersection
local function ray_aabb_intersection(origin, dir, bmin, bmax)
	local tmin = -math.huge
	local tmax = math.huge
	local axes = {"x", "y", "z"}
	for i = 1, 3 do
		local axis = axes[i]
		local d = dir[axis]
		if math.abs(d) < 1e-6 then
			if origin[axis] < bmin[axis] or origin[axis] > bmax[axis] then
				return nil
			end
		else
			local inv_d = 1.0 / d
			local t0 = (bmin[axis] - origin[axis]) * inv_d
			local t1 = (bmax[axis] - origin[axis]) * inv_d
			if t0 > t1 then
				t0, t1 = t1, t0
			end
			tmin = math.max(tmin, t0)
			tmax = math.min(tmax, t1)
			if tmax < tmin then
				return nil
			end
		end
	end
	if tmax < 0 then
		return nil
	end
	local t = (tmin >= 0) and tmin or tmax
	return vector.add(origin, vector.multiply(dir, t))
end
stand.ray_aabb_intersection = ray_aabb_intersection

---Resolves the exact raycast hit point on an armor stand node.
---@param pos vector Node position
---@param player ObjectRef Player reference
---@param pointed_thing table? Pointed thing table from engine callback
---@return vector? hit_point
local function resolve_stand_intersection(pos, player, pointed_thing)
	if pointed_thing and pointed_thing.intersection_point then
		return pointed_thing.intersection_point
	end
	if not player or not player:is_player() then
		return nil
	end

	local ppos = player:get_pos()
	if not ppos then
		return nil
	end

	local eye_h = 1.47
	local props = player:get_properties()
	if props and props.eye_height then
		eye_h = props.eye_height
	end
	local eye_pos = vector.add(ppos, vector.new(0, eye_h, 0))
	local eye_off = player:get_eye_offset()
	if eye_off then
		eye_pos = vector.add(eye_pos, vector.multiply(eye_off, 0.1))
	end
	local look_dir = player:get_look_dir()
	if not look_dir then
		return nil
	end

	-- 1. Try engine Raycast if available
	local ray_end = vector.add(eye_pos, vector.multiply(look_dir, 6))
	local ray = Raycast(eye_pos, ray_end, false, false)
	if ray then
		for pt in ray do
			if pt.type == "node" and vector.equals(pt.under, pos) and pt.intersection_point then
				return pt.intersection_point
			end
		end
	end

	-- 2. Analytical ray-AABB fallback against stand node selection box [-0.35, -0.5, -0.35] to [0.35, 1.4, 0.35]
	return ray_aabb_intersection(
		eye_pos,
		look_dir,
		vector.new(pos.x - 0.35, pos.y - 0.5, pos.z - 0.35),
		vector.new(pos.x + 0.35, pos.y + 1.4, pos.z + 0.35)
	)
end
stand.resolve_stand_intersection = resolve_stand_intersection

---Handles Shift + LMB full armor outfit and weapon swap between player and stand.
---@param pos vector Node position
---@param player ObjectRef Player reference
---@param _pointed_thing table? Pointed thing data (unused)
---@param is_locked boolean Whether the stand is owner-locked
---@return boolean handled
function stand.handle_sneak_punch(pos, player, _pointed_thing, is_locked)
	return stand.swap_armor(pos, player, is_locked)
end

---Takes all mounted armor pieces and weapons from stand and moves them to player inventory.
---@param pos vector Stand coordinates
---@param player ObjectRef Player reference
---@param is_locked boolean? Whether the stand is owner-locked
---@return boolean success
function stand.take_all_armor(pos, player, is_locked)
	if not can_interact(pos, player, is_locked) then return false end
	local name = player:get_player_name()
	local meta = core.get_meta(pos)
	local sinv = meta:get_inventory()
	if not sinv then return false end
	if sinv:get_size("armor") < 6 then
		sinv:set_size("armor", 6)
	end

	local minv = player:get_inventory()
	local changed = false
	for idx = 1, 6 do
		local s_stack = sinv:get_stack("armor", idx)
		if s_stack and not s_stack:is_empty() then
			if minv:room_for_item("main", s_stack) then
				minv:add_item("main", s_stack)
			else
				core.add_item(pos, s_stack)
			end
			sinv:set_stack("armor", idx, ItemStack(""))
			changed = true
		end
	end

	if changed then
		update_stand_entity(pos)
		local sounds = constants.SOUNDS
		if sounds and sounds.unequip then
			core.sound_play(sounds.unequip, {pos = pos, gain = 0.8, max_hear_distance = 16.0})
		end
		core.show_formspec(name, "x_player_armor:stand_" .. pos.x .. "_" .. pos.y .. "_" .. pos.z, stand.get_stand_formspec(pos, player))
	end
	return changed
end

---Dispatches a registered callback event across listeners.
---@param event string
---@param ... any
function stand.run_callbacks(event, ...)
	local list = stand.callbacks[event]
	if list then
		for i = 1, #list do
			list[i](...)
		end
	end
end

---Registers an on_equip callback for armor stands.
---@param func fun(pos: vector, slot: number, stack: ItemStack, player: ObjectRef)
function stand.register_on_equip(func)
	table.insert(stand.callbacks.on_equip, func)
end

---Registers an on_take callback for armor stands.
---@param func fun(pos: vector, slot: number, stack: ItemStack, player: ObjectRef)
function stand.register_on_take(func)
	table.insert(stand.callbacks.on_take, func)
end

---Registers an on_swap callback for armor stands.
---@param func fun(pos: vector, player: ObjectRef)
function stand.register_on_swap(func)
	table.insert(stand.callbacks.on_swap, func)
end

---Returns the audio configuration table for armor stand nodes.
---@return table
local function get_stand_node_sounds()
	local sounds = {
		dig = {name = constants.SOUNDS.stand_dig, gain = 0.5},
		dug = {name = constants.SOUNDS.stand_dug, gain = 0.8},
		place = {name = constants.SOUNDS.stand_place, gain = 0.8},
		footstep = {name = constants.SOUNDS.stand_footstep, gain = 0.4},
	}
	local default_mod = rawget(_G, "default")
	if core.get_modpath("default") and default_mod and default_mod.node_sound_wood_defaults then
		return default_mod.node_sound_wood_defaults(sounds)
	end
	return sounds
end

---Registers an armor stand node variant.
---@param subname string Node subname (e.g. "stand", "locked_stand")
---@param def table Node configuration definition
local function register_stand_node(subname, def)
	local is_locked = def.is_locked == true

	core.register_node("x_player_armor:" .. subname, {
		description = def.description,
		short_description = def.short_description,
		drawtype = "mesh",
		mesh = constants.MODELS.stand,
		visual_scale = 1.0, -- glTF 10 units = 1 node standard
		tiles = {def.texture},
		inventory_image = def.inventory_image or def.texture,
		wield_image = def.wield_image or def.inventory_image or def.texture,
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		walkable = true,
		selection_box = {
			type = "fixed",
			fixed = {-0.35, -0.5, -0.35, 0.35, 1.4, 0.35},
		},
		collision_box = {
			type = "fixed",
			fixed = {-0.35, -0.5, -0.35, 0.35, 1.4, 0.35},
		},
		groups = {choppy = 2, oddly_breakable_by_hand = 2},
		sounds = get_stand_node_sounds(),

		on_construct = function(pos)
			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("armor", 6)
			update_stand_entity(pos)
		end,

		after_place_node = function(pos, placer)
			local meta = core.get_meta(pos)
			if placer and placer:is_player() then
				local pname = placer:get_player_name()
				if is_locked then
					meta:set_string("owner", pname)
				else
					meta:set_string("owner", "")
					meta:set_string("placer", pname)
				end
			end
			update_stand_entity(pos)
		end,

		can_dig = function(pos, player)
			if not can_interact(pos, player, is_locked) then
				return false
			end
			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:is_empty("armor")
		end,

		on_destruct = function(pos)
			local obj = get_stand_entity(pos)
			if obj and obj:is_valid() then
				local luaent = obj:get_luaentity()
				if luaent then
					luaent._intentional_removal = true
				end
				obj:remove()
			end

			local shield_obj = get_stand_shield(pos)
			if shield_obj and shield_obj:is_valid() then
				local sluaent = shield_obj:get_luaentity()
				if sluaent then
					sluaent._intentional_removal = true
				end
				shield_obj:remove()
			end

			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()
			local list = inv:get_list("armor")
			if list then
				for i = 1, #list do
					local stack = list[i]
					if stack and not stack:is_empty() then
						core.add_item(pos, stack)
					end
				end
			end
		end,

		on_punch = function(pos, _node, puncher, pointed_thing)
			if not puncher or not puncher:is_player() then return end
			local ctrl = puncher:get_player_control()
			if ctrl and ctrl.sneak then
				return stand.handle_sneak_punch(pos, puncher, pointed_thing, is_locked)
			end
		end,

		on_rightclick = function(pos, _node, clicker, itemstack)
			if not clicker or not clicker:is_player() then return itemstack end
			if not can_interact(pos, clicker, is_locked) then
				core.chat_send_player(clicker:get_player_name(), S("You do not have permission to access this armor stand."))
				return itemstack
			end

			local meta = core.get_meta(pos)
			local sinv = meta:get_inventory()
			if sinv and sinv:get_size("armor") < 6 then
				sinv:set_size("armor", 6)
			end

			-- Open Formspec Version 7 Wardrobe GUI
			local name = clicker:get_player_name()
			core.show_formspec(name, "x_player_armor:stand_" .. pos.x .. "_" .. pos.y .. "_" .. pos.z, stand.get_stand_formspec(pos, clicker))
			return itemstack
		end,

		on_rotate = function(pos, node, _user, mode)
			if mode == 1 or mode == "rotate_face" then
				node.param2 = (node.param2 + 1) % 4
				core.swap_node(pos, node)
				local obj = get_stand_entity(pos)
				if obj and obj:is_valid() then
					local dir = core.facedir_to_dir(node.param2)
					obj:set_yaw((core.dir_to_yaw(dir) + math.pi) % (2 * math.pi))
				end
				return true
			end
			return false
		end,

		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if listname ~= "armor" then return 0 end
			if not can_interact(pos, player, is_locked) then return 0 end
			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()
			if inv and inv:get_size("armor") < 6 then
				inv:set_size("armor", 6)
			end
			if is_valid_stand_item(stack, index) then
				return 1
			end
			return 0
		end,

		allow_metadata_inventory_take = function(pos, listname, _index, stack, player)
			if listname ~= "armor" then return 0 end
			if not can_interact(pos, player, is_locked) then return 0 end
			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()
			if inv and inv:get_size("armor") < 6 then
				inv:set_size("armor", 6)
			end
			return stack:get_count()
		end,

		allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
			if from_list ~= "armor" or to_list ~= "armor" then return 0 end
			if not can_interact(pos, player, is_locked) then return 0 end
			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()
			if inv and inv:get_size("armor") < 6 then
				inv:set_size("armor", 6)
			end
			local stack = inv:get_stack(from_list, from_index)
			if is_valid_stand_item(stack, to_index) then
				return count
			end
			return 0
		end,

		on_metadata_inventory_put = function(pos, _listname, _index, _stack, _player)
			update_stand_entity(pos)
		end,

		on_metadata_inventory_take = function(pos, _listname, _index, _stack, _player)
			update_stand_entity(pos)
		end,

		on_metadata_inventory_move = function(pos, _from_list, _from_index, _to_list, _to_index, _count, _player)
			update_stand_entity(pos)
		end,

		on_receive_fields = function(pos, _formname, fields, sender)
			if not sender or not sender:is_player() then return end
			if fields.quit or fields.btn_close then return true end
			if fields.btn_swap_armor then
				stand.swap_armor(pos, sender, is_locked)
				core.show_formspec(sender:get_player_name(), "x_player_armor:stand_" .. pos.x .. "_" .. pos.y .. "_" .. pos.z, stand.get_stand_formspec(pos, sender))
				return true
			elseif fields.btn_take_all then
				stand.take_all_armor(pos, sender, is_locked)
				return true
			end
		end,
	})
end

-- 1. Unlocked Public Armor Stand
register_stand_node("stand", {
	description = utils.format_armor_stand_tooltip(false),
	short_description = S("Armor Stand"),
	texture = "x_player_armor_stand_shared.png",
	inventory_image = "x_player_armor_stand_inv.png",
	wield_image = "x_player_armor_stand_inv.png",
	is_locked = false,
})

-- 2. Owner-Locked Armor Stand
register_stand_node("locked_stand", {
	description = utils.format_armor_stand_tooltip(true),
	short_description = S("Locked Armor Stand"),
	texture = "x_player_armor_stand_locked.png",
	inventory_image = "x_player_armor_stand_locked_inv.png",
	wield_image = "x_player_armor_stand_locked_inv.png",
	is_locked = true,
})

-- Dispatch player button interactions for armor stand formspecs
core.register_on_player_receive_fields(function(player, formname, fields)
	if not player or not player:is_player() then return end
	if fields.quit or fields.btn_close then return true end

	local x, y, z = formname:match("^x_player_armor:stand_([%-0-9]+)_([%-0-9]+)_([%-0-9]+)$")
	if not x or not y or not z then return end
	local pos = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
	local node = core.get_node(pos)
	local is_locked = (node.name == "x_player_armor:locked_stand")

	if fields.btn_swap_armor then
		stand.swap_armor(pos, player, is_locked)
		core.show_formspec(player:get_player_name(), formname, stand.get_stand_formspec(pos, player))
	elseif fields.btn_take_all then
		stand.take_all_armor(pos, player, is_locked)
	end
end)

-- Re-spawn display entity when mapblock loads
core.register_lbm({
	name = "x_player_armor:restore_stand_entities",
	nodenames = {"x_player_armor:stand", "x_player_armor:locked_stand"},
	run_at_every_load = true,
	action = function(pos)
		update_stand_entity(pos)
	end,
})

-- Backward compatibility aliases
core.register_alias("3d_armor_stand:armor_stand", "x_player_armor:stand")
core.register_alias("3d_armor_stand:armor_stand_top", "x_player_armor:stand")
core.register_alias("3d_armor_stand:locked_armor_stand", "x_player_armor:locked_stand")
core.register_alias("3d_armor_stand:armor_stand_locked", "x_player_armor:locked_stand")

stand.update_stand_entity = update_stand_entity
stand.get_stand_entity = get_stand_entity
stand.get_stand_shield = get_stand_shield
x_player_armor.stand = stand
return stand
