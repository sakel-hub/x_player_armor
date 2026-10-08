---@class XPlayerArmorInventory
local inventory = {}

local constants = x_player_armor.constants

---Validates whether an item matches an armor slot index.
---@param stack ItemStack
---@param slot_idx number
---@return boolean valid
local function is_valid_slot_item(stack, slot_idx)
	if not stack or stack:is_empty() then
		return false
	end
	local item_name = stack:get_name()
	local resolved_name = core.registered_aliases[item_name] or item_name
	local def = core.registered_tools[resolved_name] or core.registered_items[resolved_name] or stack:get_definition()
	if not def then
		return false
	end

	local target_element = constants.SLOT_ELEMENTS[slot_idx]
	if not target_element then
		-- Slot 6 is auxiliary; accepts any valid armor piece, shield, weapon, tool, accessory, or held item
		return true
	end

	if not def.groups then
		return false
	end

	local req_group = constants.ELEMENT_GROUPS[target_element]
	return (def.groups[req_group] or 0) > 0
end
inventory.is_valid_slot_item = is_valid_slot_item

local ELEMENT_TO_SLOT = {
	head = 1,
	torso = 2,
	legs = 3,
	feet = 4,
	shield = 5,
}

---Resolves the armor element for an item stack.
---@param stack ItemStack
---@return string? element ("head", "torso", "legs", "feet", "shield")
local function get_stack_element(stack)
	if not stack or stack:is_empty() then return nil end
	local item_name = stack:get_name()
	local resolved_name = core.registered_aliases[item_name] or item_name
	local def = core.registered_tools[resolved_name] or core.registered_items[resolved_name] or stack:get_definition()
	if not def or not def.groups then return nil end
	for element, group in pairs(constants.ELEMENT_GROUPS) do
		if (def.groups[group] or 0) > 0 then
			return element
		end
	end
	return nil
end

---Plays equip or unequip audio effect for a player.
---@param player ObjectRef
---@param sound_name string
local function play_sound(player, sound_name)
	if not constants.ENABLE_SOUNDS then return end
	local pos = player:get_pos()
	if not pos then return end
	core.sound_play(sound_name, {
		pos = pos,
		gain = 0.8,
		max_hear_distance = 16.0,
	})
end

---Resolves custom or fallback sound effect for an armor item stack.
---@param stack ItemStack
---@param sound_type string "equip"|"unequip"
---@param default_sound string
---@return string sound_name
local function get_item_sound(stack, sound_type, default_sound)
	if not stack or stack:is_empty() then
		return default_sound
	end
	local iname = stack:get_name()
	local def = stack:get_definition() or (x_player_armor.registered_armors and x_player_armor.registered_armors[iname])
	if def then
		if def.sounds and def.sounds[sound_type] then
			return def.sounds[sound_type]
		end
		if def["sound_" .. sound_type] then
			return def["sound_" .. sound_type]
		end
	end
	return default_sound
end

---Serializes the player's armor inventory to metadata with dual persistence for 3d_armor compatibility.
---@param player ObjectRef
---@param inv InvRef
local function save_inventory(player, inv)
	local meta = player:get_meta()
	local list = inv:get_list("armor")
	if not list then return end

	local serialized = {}
	for i = 1, #list do
		serialized[i] = list[i]:to_string()
	end
	local serialized_str = core.serialize(serialized)
	meta:set_string("x_player_armor_inventory", serialized_str)
	meta:set_string("3d_armor_inventory", serialized_str)
end
inventory.save_inventory = save_inventory

---Reconciles and sorts items into their matching element slots.
---@param inv InvRef
local function reconcile_slots(inv)
	local pool = {}
	for idx = 1, 6 do
		local stack = inv:get_stack("armor", idx)
		if stack and not stack:is_empty() then
			table.insert(pool, stack)
		end
	end

	-- Clear all slots
	for idx = 1, 6 do
		inv:set_stack("armor", idx, ItemStack(""))
	end

	local unassigned = {}
	-- Pass 1: Assign matching elements to their designated primary slots
	for _, stack in ipairs(pool) do
		local elem = get_stack_element(stack)
		local target_slot = elem and ELEMENT_TO_SLOT[elem]
		if target_slot and inv:get_stack("armor", target_slot):is_empty() then
			inv:set_stack("armor", target_slot, stack)
		else
			table.insert(unassigned, stack)
		end
	end

	-- Pass 2: Place any unassigned or extra pieces into slot 6 or remaining empty slots
	for _, stack in ipairs(unassigned) do
		for idx = 6, 1, -1 do
			if inv:get_stack("armor", idx):is_empty() and is_valid_slot_item(stack, idx) then
				inv:set_stack("armor", idx, stack)
				break
			end
		end
	end
end

---Loads and migrates armor inventory for a player.
---@param player ObjectRef
---@param inv InvRef
local function load_inventory(player, inv)
	local meta = player:get_meta()
	local raw = meta:get_string("x_player_armor_inventory")
	local items = nil

	if raw and raw ~= "" then
		items = core.deserialize(raw)
	else
		-- Legacy 3d_armor_inventory migration
		local legacy_raw = meta:get_string("3d_armor_inventory")
		if legacy_raw and legacy_raw ~= "" then
			items = core.deserialize(legacy_raw)
			core.log("action", "[x_player_armor] Migrated legacy armor inventory for " .. player:get_player_name())
		end
	end

	inv:set_size("armor", 6)
	if type(items) == "table" then
		for idx = 1, 6 do
			local item_str = items[idx] or items[tostring(idx)]
			if item_str and type(item_str) == "string" and item_str ~= "" then
				local stack = ItemStack(item_str)
				inv:set_stack("armor", idx, stack)
			end
		end
	end

	-- Automatically reconcile slots so every piece matches its designated element placeholder
	reconcile_slots(inv)
	save_inventory(player, inv)
end

---Initializes detached inventory callbacks and registers detached inventory for a player.
---@param player ObjectRef
function inventory.init_player_inventory(player)
	local name = player:get_player_name()
	local inv_name = name .. "_armor"

	local inv = core.create_detached_inventory(inv_name, {
		allow_put = function(_inv, listname, index, stack, player_ref)
			if listname ~= "armor" then return 0 end
			if player_ref:get_player_name() ~= name then return 0 end
			if is_valid_slot_item(stack, index) then
				return 1
			end
			return 0
		end,

		allow_take = function(_inv, listname, _index, stack, player_ref)
			if listname ~= "armor" then return 0 end
			if player_ref:get_player_name() ~= name then return 0 end
			local def = stack:get_definition()
			if def and def.groups and (def.groups.cursed == 1 or def.groups.armor_cursed == 1) then
				return 0
			end
			return stack:get_count()
		end,

		allow_move = function(inv_ref, from_list, from_index, to_list, to_index, count, player_ref)
			if from_list ~= "armor" or to_list ~= "armor" then return 0 end
			if player_ref:get_player_name() ~= name then return 0 end
			local stack = inv_ref:get_stack(from_list, from_index)
			if is_valid_slot_item(stack, to_index) then
				return count
			end
			return 0
		end,

		on_put = function(inv_ref, _listname, index, stack, player_ref)
			save_inventory(player_ref, inv_ref)
			play_sound(player_ref, get_item_sound(stack, "equip", constants.SOUNDS.equip))
			x_player_armor.set_player_armor(player_ref)
			x_player_armor.update_player_visuals(player_ref)
			x_player_armor.run_callbacks("on_equip", player_ref, index, stack)
			x_player_armor.compat_x_player_api.on_equip(player_ref, stack:get_name())
			x_player_armor.run_callbacks("on_update", player_ref)
			x_player_armor.ui.refresh_player_formspec(player_ref)
		end,

		on_take = function(inv_ref, _listname, index, stack, player_ref)
			save_inventory(player_ref, inv_ref)
			play_sound(player_ref, get_item_sound(stack, "unequip", constants.SOUNDS.unequip))
			x_player_armor.set_player_armor(player_ref)
			x_player_armor.update_player_visuals(player_ref)
			x_player_armor.run_callbacks("on_unequip", player_ref, index, stack)
			x_player_armor.run_callbacks("on_update", player_ref)
			x_player_armor.ui.refresh_player_formspec(player_ref)
		end,

		on_move = function(inv_ref, _from_list, _from_index, _to_list, _to_index, _count, player_ref)
			save_inventory(player_ref, inv_ref)
			x_player_armor.set_player_armor(player_ref)
			x_player_armor.update_player_visuals(player_ref)
			x_player_armor.run_callbacks("on_update", player_ref)
			x_player_armor.ui.refresh_player_formspec(player_ref)
		end,
	}, name)

	load_inventory(player, inv)
end

---Equips an armor item into the player's appropriate slot.
---Returns displaced ItemStack (or empty ItemStack if empty slot), or nil on failure.
---@param player ObjectRef
---@param itemstack ItemStack|string
---@return ItemStack|nil displaced_stack
function inventory.equip_item(player, itemstack)
	local _, inv = x_player_armor.get_valid_player(player)
	if not inv or not itemstack then
		return nil
	end
	if type(itemstack) == "string" then
		itemstack = ItemStack(itemstack)
	end
	if itemstack:is_empty() then
		return nil
	end

	local def = itemstack:get_definition()
	if not def or not def.groups then
		return nil
	end

	-- Find matching slot
	local target_idx = nil
	for idx, element in ipairs(constants.SLOT_ELEMENTS) do
		local req_group = constants.ELEMENT_GROUPS[element]
		if (def.groups[req_group] or 0) > 0 then
			target_idx = idx
			break
		end
	end

	-- Fallback to auxiliary slot 6 for extra or custom elements
	if not target_idx then
		if is_valid_slot_item(itemstack, 6) then
			target_idx = 6
		else
			return nil
		end
	end

	local old_stack = inv:get_stack("armor", target_idx)
	if not old_stack:is_empty() then
		local odef = old_stack:get_definition()
		if odef and odef.groups and (odef.groups.cursed == 1 or odef.groups.armor_cursed == 1) then
			return nil
		end
	end

	local to_put = itemstack:take_item(1)
	inv:set_stack("armor", target_idx, to_put)
	save_inventory(player, inv)

	if not old_stack:is_empty() then
		local player_inv = player:get_inventory()
		if player_inv:room_for_item("main", old_stack) then
			player_inv:add_item("main", old_stack)
		else
			core.add_item(player:get_pos(), old_stack)
		end
	end

	play_sound(player, get_item_sound(to_put, "equip", constants.SOUNDS.equip))
	x_player_armor.set_player_armor(player)
	x_player_armor.update_player_visuals(player)
	x_player_armor.run_callbacks("on_equip", player, target_idx, to_put)
	x_player_armor.compat_x_player_api.on_equip(player, to_put:get_name())
	x_player_armor.run_callbacks("on_update", player)
	x_player_armor.ui.refresh_player_formspec(player)
	return old_stack
end

---Unequips an armor item by slot element or index.
---@param player ObjectRef Target player
---@param element string|number Slot element name ("head", "torso", etc.) or slot index (1..6)
---@return ItemStack unequipped_stack
function inventory.unequip_element(player, element)
	local _, inv = x_player_armor.get_valid_player(player)
	if not inv then
		return ItemStack("")
	end

	local target_idx = nil
	if type(element) == "number" and element >= 1 and element <= 6 then
		target_idx = element
	else
		for idx, el in ipairs(constants.SLOT_ELEMENTS) do
			if el == element then
				target_idx = idx
				break
			end
		end
	end

	if not target_idx then
		return ItemStack("")
	end

	local stack = inv:get_stack("armor", target_idx)
	if stack:is_empty() then
		return ItemStack("")
	end

	local sdef = stack:get_definition()
	if sdef and sdef.groups and (sdef.groups.cursed == 1 or sdef.groups.armor_cursed == 1) then
		return ItemStack("")
	end

	inv:set_stack("armor", target_idx, ItemStack(""))
	save_inventory(player, inv)
	play_sound(player, get_item_sound(stack, "unequip", constants.SOUNDS.unequip))
	x_player_armor.set_player_armor(player)
	x_player_armor.update_player_visuals(player)
	x_player_armor.run_callbacks("on_unequip", player, target_idx, stack)
	x_player_armor.run_callbacks("on_update", player)
	x_player_armor.ui.refresh_player_formspec(player)
	return stack
end

---Handles armor drops upon player death.
---@param player ObjectRef
function inventory.handle_player_death(player)
	local _, inv = x_player_armor.get_valid_player(player)
	if not inv then return end

	local list = inv:get_list("armor")
	if not list then return end

	local pos = player:get_pos()
	local bones_installed = core.get_modpath("bones") ~= nil

	for i = 1, #list do
		local stack = list[i]
		if not stack:is_empty() then
			local def = stack:get_definition()
			local is_soulbound = def and def.groups and (def.groups.soulbound == 1 or def.groups.armor_soulbound == 1)
			if not is_soulbound then
				if constants.DESTROY_ON_DEATH then
					inv:set_stack("armor", i, ItemStack(""))
				elseif constants.DROP_ON_DEATH then
					inv:set_stack("armor", i, ItemStack(""))
					if not bones_installed and pos then
						core.add_item(pos, stack)
					else
						-- Add to player main inventory so standard bones mod collects it
						local pinv = player:get_inventory()
						pinv:add_item("main", stack)
					end
				end
			end
		end
	end

	save_inventory(player, inv)
	x_player_armor.set_player_armor(player)
	x_player_armor.update_player_visuals(player)
end

core.register_on_joinplayer(function(player)
	inventory.init_player_inventory(player)
	core.after(0.1, function()
		if player:is_player() then
			x_player_armor.visuals.cleanup_orphaned_visuals()
			x_player_armor.set_player_armor(player)
			x_player_armor.update_player_visuals(player)
		end
	end)
end)

core.register_on_dieplayer(function(player)
	inventory.handle_player_death(player)
end)

x_player_armor.inventory = inventory
return inventory
