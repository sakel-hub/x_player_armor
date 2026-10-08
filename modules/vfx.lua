---@class XPlayerArmorVFX
local vfx = {}

local utils = x_player_armor.utils

-- Static reusable particle texpools and tween tables for optimal multiplayer performance
-- Eliminates table allocations inside high-frequency combat callbacks.
local HEAL_TEXPOOL = {
	{
		name = "x_player_armor_particles.png^[verticalframe:8:0",
		blend = "add",
		scale_tween = {start = 1.5, finish = 0.3, 1.5, 0.3},
		alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
	},
	{
		name = "x_player_armor_particles.png^[verticalframe:8:1",
		blend = "add",
		scale_tween = {start = 1.6, finish = 0.3, 1.6, 0.3},
		alpha_tween = {start = 0.95, finish = 0.0, 0.95, 0.0},
	},
	{
		name = "x_player_armor_particles.png^[verticalframe:8:2",
		blend = "add",
		scale_tween = {start = 1.3, finish = 0.2, 1.3, 0.2},
		alpha_tween = {start = 0.9, finish = 0.0, 0.9, 0.0},
	},
}

local SHIELD_TEXPOOL = {
	{
		name = "x_player_armor_particles.png^[verticalframe:8:3",
		blend = "add",
		scale_tween = {start = 2.0, finish = 0.3, 2.0, 0.3},
		alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
	},
	{
		name = "x_player_armor_particles.png^[verticalframe:8:4",
		blend = "add",
		scale_tween = {start = 1.5, finish = 0.2, 1.5, 0.2},
		alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
	},
}

local BREAK_TEXPOOLS = {
	metal = {
		{
			name = "x_player_armor_particles.png^[verticalframe:8:5",
			blend = "alpha",
			scale_tween = {start = 2.2, finish = 0.7, 2.2, 0.7},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
		{
			name = "x_player_armor_particles.png^[verticalframe:8:4",
			blend = "add",
			scale_tween = {start = 1.4, finish = 0.2, 1.4, 0.2},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
	},
	crystal = {
		{
			name = "x_player_armor_particles.png^[verticalframe:8:6",
			blend = "add",
			scale_tween = {start = 2.2, finish = 0.7, 2.2, 0.7},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
		{
			name = "x_player_armor_particles.png^[verticalframe:8:4",
			blend = "add",
			scale_tween = {start = 1.4, finish = 0.2, 1.4, 0.2},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
	},
	wood = {
		{
			name = "x_player_armor_particles.png^[verticalframe:8:7",
			blend = "alpha",
			scale_tween = {start = 2.2, finish = 0.7, 2.2, 0.7},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
		{
			name = "x_player_armor_particles.png^[verticalframe:8:4",
			blend = "add",
			scale_tween = {start = 1.4, finish = 0.2, 1.4, 0.2},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
	},
}

local IMPACT_TEXPOOLS = {
	metal = {
		{
			name = "x_player_armor_particles.png^[verticalframe:8:4",
			blend = "add",
			scale_tween = {start = 1.4, finish = 0.2, 1.4, 0.2},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
		{
			name = "x_player_armor_particles.png^[verticalframe:8:5",
			blend = "alpha",
			scale_tween = {start = 1.2, finish = 0.3, 1.2, 0.3},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
	},
	crystal = {
		{
			name = "x_player_armor_particles.png^[verticalframe:8:4",
			blend = "add",
			scale_tween = {start = 1.5, finish = 0.2, 1.5, 0.2},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
		{
			name = "x_player_armor_particles.png^[verticalframe:8:6",
			blend = "add",
			scale_tween = {start = 1.3, finish = 0.3, 1.3, 0.3},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
	},
	wood = {
		{
			name = "x_player_armor_particles.png^[verticalframe:8:4",
			blend = "add",
			scale_tween = {start = 1.3, finish = 0.2, 1.3, 0.2},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
		{
			name = "x_player_armor_particles.png^[verticalframe:8:7",
			blend = "alpha",
			scale_tween = {start = 1.2, finish = 0.3, 1.2, 0.3},
			alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		},
	},
}


---Spawns a particlespawner populated with both modern structured definitions and legacy fallback keys.
---Ensures 100% compatibility across all Luanti engine versions while keeping code DRY and optimized
---for multiplayer performance with targeted networking support.
---@param def table Modern structured particlespawner definition
---@return integer|nil spawner_id ID of registered particlespawner or nil
function vfx.spawn_particles(def)
	if not def then return nil end
	if not def.playername and def.player then
		def.playername = utils.get_player_name(def.player)
	end
	if def.pos then
		def.minpos = def.minpos or def.pos.min
		def.maxpos = def.maxpos or def.pos.max
	end
	if def.vel then
		def.minvel = def.minvel or def.vel.min
		def.maxvel = def.maxvel or def.vel.max
	end
	if def.acc then
		def.minacc = def.minacc or def.acc.min
		def.maxacc = def.maxacc or def.acc.max
	end
	if def.exptime then
		def.minexptime = def.minexptime or def.exptime.min
		def.maxexptime = def.maxexptime or def.exptime.max
	end
	if def.size then
		def.minsize = def.minsize or def.size.min
		def.maxsize = def.maxsize or def.size.max
	end
	if def.texpool and #def.texpool > 0 and not def.texture then
		def.texture = def.texpool[1].name
	end
	return core.add_particlespawner(def)
end

---Spawns modern regenerative healing ward particles around a position.
---Optimized for multiplayer: lean particle count, non-colliding, and supports targeted player transmission.
---@param pos vector Center position
---@param player (ObjectRef|string)? Optional player reference or playername for targeted networking
---@return integer|nil spawner_id
function vfx.spawn_heal_particles(pos, player)
	if not pos then return nil end
	return vfx.spawn_particles({
		amount = 8,
		time = 0.2,
		playername = utils.get_player_name(player),
		pos = {
			min = {x = pos.x - 0.45, y = pos.y + 0.2, z = pos.z - 0.45},
			max = {x = pos.x + 0.45, y = pos.y + 1.6, z = pos.z + 0.45},
		},
		vel = {
			min = {x = -0.35, y = 0.7, z = -0.35},
			max = {x = 0.35, y = 1.5, z = 0.35},
		},
		acc = {
			min = {x = -0.05, y = 0.2, z = -0.05},
			max = {x = 0.05, y = 0.6, z = 0.05},
		},
		jitter = {
			min = {x = -0.2, y = -0.1, z = -0.2},
			max = {x = 0.2, y = 0.1, z = 0.2},
		},
		drag = {
			min = {x = 0.05, y = 0.05, z = 0.05},
			max = {x = 0.15, y = 0.15, z = 0.15},
		},
		bounce = {
			min = {x = 0, y = 0, z = 0},
			max = {x = 0, y = 0, z = 0},
		},
		exptime = {min = 0.4, max = 0.8},
		size = {min = 1.4, max = 2.6},
		collisiondetection = false,
		collision_removal = false,
		object_collision = false,
		glow = 12,
		scale_tween = {start = 1.4, finish = 0.3, 1.4, 0.3},
		alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		texpool = HEAL_TEXPOOL,
	})
end

---Spawns modern shield block deflection sparks at a position.
---Optimized for multiplayer: fast burst, immediate collision cleanup, and optional targeted networking.
---@param pos vector Center position
---@param player (ObjectRef|string)? Optional player reference or playername for targeted networking
---@return integer|nil spawner_id
function vfx.spawn_shield_block_particles(pos, player)
	if not pos then return nil end
	return vfx.spawn_particles({
		amount = 8,
		time = 0.15,
		playername = utils.get_player_name(player),
		pos = {
			min = {x = pos.x - 0.15, y = pos.y - 0.15, z = pos.z - 0.15},
			max = {x = pos.x + 0.15, y = pos.y + 0.15, z = pos.z + 0.15},
		},
		vel = {
			min = {x = -1.6, y = -0.2, z = -1.6},
			max = {x = 1.6, y = 1.4, z = 1.6},
		},
		acc = {
			min = {x = -0.3, y = -3.5, z = -0.3},
			max = {x = 0.3, y = -1.0, z = 0.3},
		},
		jitter = {
			min = {x = -0.3, y = -0.3, z = -0.3},
			max = {x = 0.3, y = 0.3, z = 0.3},
		},
		drag = {
			min = {x = 0.25, y = 0.25, z = 0.25},
			max = {x = 0.5, y = 0.5, z = 0.5},
		},
		bounce = {
			min = {x = 0.3, y = 0.3, z = 0.3},
			max = {x = 0.6, y = 0.6, z = 0.6},
		},
		exptime = {min = 0.25, max = 0.5},
		size = {min = 1.4, max = 2.8},
		collisiondetection = true,
		collision_removal = true,
		object_collision = false,
		glow = 14,
		scale_tween = {start = 1.8, finish = 0.25, 1.8, 0.25},
		alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		texpool = SHIELD_TEXPOOL,
	})
end

---Spawns modern armor destruction shatter particles matching the broken item's material.
---Optimized for multiplayer: lean shard count, short lifetime, collision removal, and optional targeted networking.
---@param pos vector Center position
---@param item_name string Name of broken armor item
---@param player (ObjectRef|string)? Optional player reference or playername for targeted networking
---@return integer|nil spawner_id
function vfx.spawn_armor_break_particles(pos, item_name, player)
	if not pos then return nil end
	local pool = BREAK_TEXPOOLS.metal
	local glow = 6

	if item_name:find("crystal") or item_name:find("diamond") then
		pool = BREAK_TEXPOOLS.crystal
		glow = 10
	elseif item_name:find("wood") or item_name:find("cactus") then
		pool = BREAK_TEXPOOLS.wood
		glow = 2
	end

	return vfx.spawn_particles({
		amount = 10,
		time = 0.2,
		playername = utils.get_player_name(player),
		pos = {
			min = {x = pos.x - 0.3, y = pos.y + 0.5, z = pos.z - 0.3},
			max = {x = pos.x + 0.3, y = pos.y + 1.4, z = pos.z + 0.3},
		},
		vel = {
			min = {x = -2.2, y = 1.0, z = -2.2},
			max = {x = 2.2, y = 3.6, z = 2.2},
		},
		acc = {
			min = {x = -0.2, y = -9.8, z = -0.2},
			max = {x = 0.2, y = -9.8, z = 0.2},
		},
		jitter = {
			min = {x = -0.2, y = -0.2, z = -0.2},
			max = {x = 0.2, y = 0.2, z = 0.2},
		},
		drag = {
			min = {x = 0.1, y = 0.1, z = 0.1},
			max = {x = 0.25, y = 0.25, z = 0.25},
		},
		bounce = {
			min = {x = 0.35, y = 0.35, z = 0.35},
			max = {x = 0.65, y = 0.65, z = 0.65},
		},
		exptime = {min = 0.4, max = 0.8},
		size = {min = 1.6, max = 3.2},
		collisiondetection = true,
		collision_removal = true,
		object_collision = false,
		glow = glow,
		scale_tween = {start = 2.2, finish = 0.7, 2.2, 0.7},
		alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		texpool = pool,
	})
end

---Spawns modern armor impact deflection sparks matching the armor's material.
---Triggered when armor absorbs incoming damage or deflects hits.
---Optimized for multiplayer: lean particle count, short burst, collision removal, and optional targeted networking.
---@param pos vector Center position
---@param dominant_material string? Material category ("metal", "crystal", "diamond", "wood", "cactus", etc.)
---@param player (ObjectRef|string)? Optional player reference or playername for targeted networking
---@return integer|nil spawner_id
function vfx.spawn_impact_particles(pos, dominant_material, player)
	if not pos then return nil end
	local pool = IMPACT_TEXPOOLS.metal
	local glow = 8

	if dominant_material == "crystal" or dominant_material == "diamond" then
		pool = IMPACT_TEXPOOLS.crystal
		glow = 12
	elseif dominant_material == "wood" or dominant_material == "cactus" then
		pool = IMPACT_TEXPOOLS.wood
		glow = 4
	end

	return vfx.spawn_particles({
		amount = 6,
		time = 0.12,
		playername = utils.get_player_name(player),
		pos = {
			min = {x = pos.x - 0.25, y = pos.y + 0.6, z = pos.z - 0.25},
			max = {x = pos.x + 0.25, y = pos.y + 1.4, z = pos.z + 0.25},
		},
		vel = {
			min = {x = -1.2, y = 0.2, z = -1.2},
			max = {x = 1.2, y = 1.6, z = 1.2},
		},
		acc = {
			min = {x = -0.2, y = -4.0, z = -0.2},
			max = {x = 0.2, y = -2.0, z = 0.2},
		},
		jitter = {
			min = {x = -0.2, y = -0.2, z = -0.2},
			max = {x = 0.2, y = 0.2, z = 0.2},
		},
		drag = {
			min = {x = 0.2, y = 0.2, z = 0.2},
			max = {x = 0.4, y = 0.4, z = 0.4},
		},
		bounce = {
			min = {x = 0.2, y = 0.2, z = 0.2},
			max = {x = 0.5, y = 0.5, z = 0.5},
		},
		exptime = {min = 0.2, max = 0.45},
		size = {min = 1.2, max = 2.4},
		collisiondetection = true,
		collision_removal = true,
		object_collision = false,
		glow = glow,
		scale_tween = {start = 1.4, finish = 0.2, 1.4, 0.2},
		alpha_tween = {start = 1.0, finish = 0.0, 1.0, 0.0},
		texpool = pool,
	})
end

x_player_armor.vfx = vfx
return vfx

