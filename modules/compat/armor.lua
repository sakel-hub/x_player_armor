-- X Player Armor - 3D Armor Full API Compatibility Shim (modules/compat/armor.lua)
-- Provides complete backwards compatibility for mods expecting global 'armor'.
-- Fully supports both colon (armor:func) and dot (armor.func) calling syntax.
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

---@class ArmorCompat
local armor = {
	_is_x_player_armor = true,
	def = x_player_armor.def,
	config = {
		init_delay = 1,
		init_times = 1,
		bones = {
			head = "Head",
			torso = "Body",
			legs = "Legs",
			feet = "Feet",
			shield = "Arm_Left",
		},
		update_time = 1,
		drop = x_player_armor.constants.DROP_ON_DEATH,
		destroy = x_player_armor.constants.DESTROY_ON_DEATH,
		level_multiplier = x_player_armor.constants.LEVEL_MULTIPLIER,
		heal_multiplier = x_player_armor.constants.HEAL_MULTIPLIER,
		material_wood = true,
		material_cactus = true,
		material_steel = true,
		material_bronze = true,
		material_diamond = true,
		material_gold = true,
		material_mithril = true,
		material_crystal = true,
		water_protect = true,
		reciprocate_damage = false,
	},
	materials = {
		wood = "group:wood",
		cactus = "default:cactus",
		steel = "default:steel_ingot",
		bronze = "default:bronze_ingot",
		diamond = "default:diamond",
		gold = "default:gold_ingot",
		mithril = "moreores:mithril_ingot",
		crystal = "ethereal:crystal_ingot",
	},
	sounds = {
		wood = "x_player_armor_hit_wood",
		cactus = "x_player_armor_hit_wood",
		steel = "x_player_armor_equip_metal",
		bronze = "x_player_armor_equip_metal",
		diamond = "x_player_armor_equip_metal",
		gold = "x_player_armor_equip_metal",
		mithril = "x_player_armor_equip_metal",
		crystal = "x_player_armor_hit_crystal",
	},
	elements = {"head", "torso", "legs", "feet", "shield"},
	physics = {"jump", "speed", "gravity"},
	attributes = {"heal", "fire", "water", "feather"},
	registered_armors = x_player_armor.registered_armors,
	registered_elements = x_player_armor.registered_elements,
	registered_materials = x_player_armor.registered_materials,
	registered_groups = x_player_armor.registered_groups,
	fire_nodes = x_player_armor.constants.FIRE_NODES,
	formspec = "",
}

armor.textures = setmetatable({}, {
	__index = function(t, pname)
		local player = core.get_player_by_name(pname)
		local pdef = rawget(x_player_armor.def, pname)
		local skin = (pdef and pdef.skin) or "x_player_armor_character.png"
		local armor_tex = player and x_player_armor.ui.get_composite_armor_texture(player) or "blank.png"
		local prev_tex = player and x_player_armor.ui.get_2d_preview_texture(player) or "character_preview.png"
		local shield_tex = "blank.png"
		if player then
			local shield_stack = x_player_armor.combat.get_equipped_shield(player)
			if shield_stack and not shield_stack:is_empty() then
				shield_tex = x_player_armor.visuals.get_item_texture(shield_stack:get_name()) or "blank.png"
			end
		end
		local data = {
			skin = skin,
			armor = armor_tex,
			wielditem = "blank.png",
			preview = prev_tex,
			shield = shield_tex,
		}
		rawset(t, pname, data)
		return data
	end,
})

---Helper resolving arguments whether called with colon (armor:fn) or dot (armor.fn)
---@param self_or_player any
---@param maybe_player any
---@param ... any
---@return any, any, any
local function resolve_args(self_or_player, maybe_player, ...)
	if self_or_player == armor then
		return maybe_player, ...
	end
	return self_or_player, maybe_player, ...
end

---Validates player reference and returns player name and detached armor inventory.
---@param self_or_player any
---@param maybe_player any
---@param _mod any
---@return string|nil name, InvRef|nil inv
function armor.get_valid_player(self_or_player, maybe_player, _mod)
	local player = resolve_args(self_or_player, maybe_player)
	return x_player_armor.get_valid_player(player)
end

---Returns a map of armor elements currently worn by the player.
---@param self_or_player any
---@param maybe_player any
---@return table<string, boolean>
function armor.get_weared_armor_elements(self_or_player, maybe_player)
	local player = resolve_args(self_or_player, maybe_player)
	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then
		return {}
	end
	local weared = {}
	local list = inv:get_list("armor")
	if not list then
		return weared
	end
	for i = 1, #list do
		local stack = list[i]
		if stack and not stack:is_empty() then
			local def = stack:get_definition()
			local groups = def and def.groups
			local item_name = stack:get_name()
			for _, element in ipairs(armor.elements) do
				if (groups and (groups["armor_" .. element] or 0) > 0) or
				   core.get_item_group(item_name, "armor_" .. element) > 0 or
				   (element == "shield" and ((groups and (groups.shield or 0) > 0) or core.get_item_group(item_name, "shield") > 0)) then
					weared[element] = true
					break
				end
			end
		end
	end
	return weared
end

---Removes all armor items from the player's equipped inventory.
---@param self_or_player any
---@param maybe_player any
function armor.remove_all(self_or_player, maybe_player)
	local player = resolve_args(self_or_player, maybe_player)
	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then
		return
	end
	for i = 1, 6 do
		inv:set_stack("armor", i, ItemStack(""))
	end
	x_player_armor.set_player_armor(player)
	x_player_armor.update_player_visuals(player)
end

---Retrieves the player's skin texture.
---@param self_or_player any
---@param maybe_player any
---@return string
function armor.get_player_skin(self_or_player, maybe_player)
	local player = resolve_args(self_or_player, maybe_player)
	if not player or not player:is_player() then
		return "x_player_armor_character.png"
	end
	local pname = player:get_player_name()
	return (armor.textures[pname] and armor.textures[pname].skin) or "x_player_armor_character.png"
end

---Updates skin texture and refreshes visual entity.
---@param self_or_player any
---@param maybe_player any
function armor.update_skin(self_or_player, maybe_player)
	local player = resolve_args(self_or_player, maybe_player)
	if not player or not player:is_player() then
		return
	end
	local pname = player:get_player_name()
	local props = player:get_properties()
	if props and props.textures and props.textures[1] and props.textures[1] ~= "" then
		if armor.textures[pname] then
			armor.textures[pname].skin = props.textures[1]
		end
	end
	x_player_armor.update_player_visuals(player)
end

---Appends preview texture string (compatibility stub).
---@param _self_or_preview any
---@param _preview any
function armor.add_preview(_self_or_preview, _preview)
	-- Handled dynamically via composite textures
end

---Returns the composite preview texture for a player.
---@param self_or_player any
---@param maybe_player any
---@return string
function armor.get_preview(self_or_player, maybe_player)
	local player = resolve_args(self_or_player, maybe_player)
	return x_player_armor.get_player_preview_texture(player)
end

---Returns the armor formspec string for a player.
---@param self_or_name any
---@param maybe_name any
---@param _page any
---@return string
function armor.get_armor_formspec(self_or_name, maybe_name, _page)
	local name_or_player = resolve_args(self_or_name, maybe_name)
	local player = type(name_or_player) == "string" and core.get_player_by_name(name_or_player) or name_or_player
	if player and player:is_player() then
		return x_player_armor.ui.get_formspec(player)
	end
	return ""
end

---Determines which armor element an item belongs to.
---@param self_or_item any
---@param maybe_item any
---@return string|nil
function armor.get_element(self_or_item, maybe_item)
	local item_name = resolve_args(self_or_item, maybe_item)
	if not item_name or item_name == "" then
		return nil
	end
	for _, element in ipairs(armor.elements) do
		if core.get_item_group(item_name, "armor_" .. element) > 0 then
			return element
		end
	end
	return nil
end

---Serializes an inventory list of ItemStacks to strings.
---@param self_or_list any
---@param maybe_list any
---@return string[]
function armor.serialize_inventory_list(self_or_list, maybe_list)
	local list = self_or_list
	if self_or_list == armor or (type(self_or_list) == "table" and (self_or_list.is_player or not self_or_list[1])) then
		list = maybe_list
	end
	local serialized = {}
	if type(list) == "table" then
		for i = 1, #list do
			local stack = list[i]
			serialized[i] = (stack and stack.to_string) and stack:to_string() or tostring(stack or "")
		end
	end
	return serialized
end

---Deserializes an array of item strings to ItemStacks.
---@param self_or_list any
---@param maybe_list any
---@return ItemStack[]
function armor.deserialize_inventory_list(self_or_list, maybe_list)
	local list = self_or_list
	if self_or_list == armor or (type(self_or_list) == "table" and (self_or_list.is_player or not self_or_list[1])) then
		list = maybe_list
	end
	local result = {}
	if type(list) == "table" then
		for i = 1, #list do
			result[i] = ItemStack(list[i] or "")
		end
	end
	return result
end

---Loads armor inventory from player metadata.
---@param self_or_player any
---@param maybe_player any
function armor.load_armor_inventory(self_or_player, maybe_player)
	local player = resolve_args(self_or_player, maybe_player)
	if not player or not player:is_player() then
		return
	end
	x_player_armor.inventory.init_player_inventory(player)
end

---Saves armor inventory to player metadata.
---@param self_or_player any
---@param maybe_player any
function armor.save_armor_inventory(self_or_player, maybe_player)
	local player = resolve_args(self_or_player, maybe_player)
	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv then
		return
	end
	local meta = player:get_meta()
	local list = inv:get_list("armor")
	if not list then
		return
	end
	local serialized = {}
	for i = 1, #list do
		serialized[i] = list[i]:to_string()
	end
	local serialized_str = core.serialize(serialized)
	meta:set_string("x_player_armor_inventory", serialized_str)
	meta:set_string("3d_armor_inventory", serialized_str)
end

---Sets stack at specific slot in detached armor inventory.
---@param self_or_player any
---@param maybe_player any
---@param i any
---@param stack any
function armor.set_inventory_stack(self_or_player, maybe_player, i, stack)
	local player, slot_idx, itemstack = resolve_args(self_or_player, maybe_player, i, stack)
	local name, inv = x_player_armor.get_valid_player(player)
	if not name or not inv or not slot_idx then
		return
	end
	local to_put = type(itemstack) == "string" and ItemStack(itemstack) or (itemstack or ItemStack(""))
	inv:set_stack("armor", slot_idx, to_put)
	armor.save_armor_inventory(player)
	x_player_armor.set_player_armor(player)
	x_player_armor.update_player_visuals(player)
	x_player_armor.run_callbacks("on_update", player)
	x_player_armor.ui.refresh_player_formspec(player)
end

---Drops an armor item at the given position.
---@param self_or_pos any
---@param maybe_pos any
---@param stack any
---@return ObjectRef|nil
function armor.drop_armor(self_or_pos, maybe_pos, stack)
	local pos, itemstack = resolve_args(self_or_pos, maybe_pos, stack)
	if not pos then
		return nil
	end
	local to_drop = type(itemstack) == "string" and ItemStack(itemstack) or itemstack
	if to_drop and not to_drop:is_empty() then
		return core.add_item(pos, to_drop)
	end
	return nil
end

---Equips an armor item into the player's armor inventory.
---Returns the displaced ItemStack (or nil on failure).
---@param self_or_player any
---@param maybe_player any
---@param stack any
---@return ItemStack|nil displaced_stack
function armor.equip(self_or_player, maybe_player, stack)
	local player, itemstack = resolve_args(self_or_player, maybe_player, stack)
	if not player or not player:is_player() then
		return nil
	end
	local to_equip = type(itemstack) == "string" and ItemStack(itemstack) or itemstack
	if not to_equip or to_equip:is_empty() then
		return nil
	end
	return x_player_armor.equip(player, to_equip)
end

---Unequips an armor item by slot element or index.
---@param self_or_player any
---@param maybe_player any
---@param element any
---@return ItemStack unequipped_stack
function armor.unequip(self_or_player, maybe_player, element)
	local player, target_element = resolve_args(self_or_player, maybe_player, element)
	if not player or not player:is_player() then
		return ItemStack("")
	end
	local elem_arg = type(target_element) == "number" and target_element or tostring(target_element or "")
	local stack = x_player_armor.unequip(player, elem_arg)
	if stack and not stack:is_empty() then
		local pinv = player:get_inventory()
		if pinv and pinv:room_for_item("main", stack) then
			pinv:add_item("main", stack)
		else
			core.add_item(player:get_pos(), stack)
		end
	end
	return stack or ItemStack("")
end

---Damages worn armor item.
---@param self_or_player any
---@param maybe_player any
---@param index any
---@param stack any
---@param uses any
---@return boolean destroyed
function armor.damage(self_or_player, maybe_player, index, stack, uses)
	local player, idx, itemstack, durability_uses = resolve_args(self_or_player, maybe_player, index, stack, uses)
	return x_player_armor.damage(player, idx, itemstack, durability_uses)
end

---Handles punch combat event.
---@param self_or_player any
---@param maybe_player any
---@param hitter any
---@param time_from_last_punch any
---@param tool_capabilities any
---@param dir any
---@param damage any
function armor.punch(self_or_player, maybe_player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	local player, punch_hitter, t_last, caps, punch_dir, dmg = resolve_args(
		self_or_player, maybe_player, hitter, time_from_last_punch, tool_capabilities, dir, damage
	)
	x_player_armor.punch(player, punch_hitter, t_last, caps, punch_dir, dmg)
end

---Re-evaluates player armor attributes, defense levels, and physics.
---@param self_or_player any
---@param maybe_player any
function armor.set_player_armor(self_or_player, maybe_player)
	local player = resolve_args(self_or_player, maybe_player)
	x_player_armor.set_player_armor(player)
end

---Updates visual attachment entities for a player.
---@param self_or_player any
---@param maybe_player any
function armor.update_player_visuals(self_or_player, maybe_player)
	local player = resolve_args(self_or_player, maybe_player)
	x_player_armor.update_player_visuals(player)
end

---Registers an armor item definition.
---@param self_or_name any
---@param maybe_name any
---@param def any
function armor.register_armor(self_or_name, maybe_name, def)
	local item_name, item_def = resolve_args(self_or_name, maybe_name, def)
	x_player_armor.register_armor(item_name, item_def)
end

---Registers a custom armor defense group.
---@param self_or_group any
---@param maybe_group any
---@param base any
function armor.register_armor_group(self_or_group, maybe_group, base)
	local group_name, base_val = resolve_args(self_or_group, maybe_group, base)
	x_player_armor.register_armor_group(group_name, base_val)
end

---Registers an on_equip callback.
---@param self_or_func any
---@param maybe_func any
function armor.register_on_equip(self_or_func, maybe_func)
	local func = resolve_args(self_or_func, maybe_func)
	x_player_armor.register_on_equip(func)
end

---Registers an on_unequip callback.
---@param self_or_func any
---@param maybe_func any
function armor.register_on_unequip(self_or_func, maybe_func)
	local func = resolve_args(self_or_func, maybe_func)
	x_player_armor.register_on_unequip(func)
end

---Registers an on_damage callback.
---@param self_or_func any
---@param maybe_func any
function armor.register_on_damage(self_or_func, maybe_func)
	local func = resolve_args(self_or_func, maybe_func)
	x_player_armor.register_on_damage(func)
end

---Registers an on_destroy callback.
---@param self_or_func any
---@param maybe_func any
function armor.register_on_destroy(self_or_func, maybe_func)
	local func = resolve_args(self_or_func, maybe_func)
	x_player_armor.register_on_destroy(func)
end

---Registers an on_update callback.
---@param self_or_func any
---@param maybe_func any
function armor.register_on_update(self_or_func, maybe_func)
	local func = resolve_args(self_or_func, maybe_func)
	x_player_armor.register_on_update(func)
end

_G.armor = armor
x_player_armor.compat_armor = armor
x_player_armor.compat.armor = armor
core.log("action", "[x_player_armor] Full 'armor' compatibility shim successfully registered.")

-- i3 Inventory Integration Shim:
-- When i3 is present, it checks `if core.global_exists"armor"` during its load phase.
-- Since x_player_armor loads after i3 (due to optional_depends), i3.modules.armor remains nil
-- and reports "3d_armor is not installed" on its Armor tab.
-- Activating i3.modules.armor here seamlessly enables the Armor tab in i3.
local function enable_i3_armor_compat()
	local i3_mod = x_player_armor.get_mod_api("i3")
	if i3_mod and i3_mod.modules then
		i3_mod.modules.armor = true
	end
end

enable_i3_armor_compat()
core.register_on_mods_loaded(enable_i3_armor_compat)

return armor
