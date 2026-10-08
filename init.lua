-- X Player Armor (x_player_armor)
-- High-performance modular player armor and shield system for Luanti
-- Author: SaKeL
-- License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)

-- Enforce minimum Luanti engine version
if not core.features or not core.register_detached_inventory_raw and not core.create_detached_inventory then
	core.log("error", "[" .. modname .. "] Luanti 5.10.0 or higher is required.")
	return
end

-- 1. Early Modpath Virtualization (Allow 3rd-party mods to detect 3d_armor/shields immediately)
dofile(modpath .. "/modules/compat/engine.lua")

-- 2. Initialize Public API Table
dofile(modpath .. "/api.lua")

-- 2. Load Modular Subsystems in Dependency Order
local modules = {
	"utils",
	"constants",
	"visuals",
	"vfx",
	"inventory",
	"effects",
	"combat",
	"items",
	"crafting",
	"ui",
	"stand",
	"shield_hud",
	"combat_hud",
	"compat",
}

for i = 1, #modules do
	local file = modpath .. "/modules/" .. modules[i] .. ".lua"
	dofile(file)
end

core.log("action", "[" .. modname .. "] v" .. x_player_armor.version .. " initialized successfully.")
