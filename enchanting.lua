local enchanting = {}
screwdriver = screwdriver or {}

function enchanting.formspec(pos, tool)
	local formspec = [[ size[9,9;]
			bgcolor[#080808BB;true]
			background[0,0;9,9;ench_ui.png]
			list[context;tool;0.9,2.9;1,1;]
			list[context;mese;2,2.9;1,1;]
			list[current_player;main;0.5,4.5;8,4;]
			image[2,2.9;1,1;mese_layout.png]
			tooltip[sharp;Your sword inflicts more damage]
			tooltip[durable;Your tool is more resistant]
			tooltip[fast;Your tool is more powerful]
			tooltip[strong;Your armor is more resistant]
			tooltip[speed;Your speed is increased] ]]
			..default.gui_slots..default.get_hotbar_bg(0.5,4.5)

	local tool_fs = {
		["tool"] = [[ image_button[3.9,0.85;4,0.92;bg_btn.png;fast;Efficiency]
			image_button[3.9,1.77;4,1.12;bg_btn.png;durable;Durability] ]],
		["armor"] = "image_button[3.9,0.85;4,0.92;bg_btn.png;strong;Strength]",
		["sword"] = "image_button[3.9,2.9;4,0.92;bg_btn.png;sharp;Sharpness]",
		["boots"] = [[ image_button[3.9,0.85;4,0.92;bg_btn.png;strong;Strength]
				image_button[3.9,1.77;4,1.12;bg_btn.png;speed;Speed] ]] }

	for cat in pairs(tool_fs) do
		if tool == cat then
			formspec = formspec..tool_fs[cat]
		end
	end

	minetest.get_meta(pos):set_string("formspec", formspec)
end

function enchanting.is_owner(pos, player)
	local meta = minetest.get_meta(pos)
	local owner_name = meta:get_string("owner")
	local player_name = player:get_player_name() or ""
	return (owner_name == player_name) or (player_name == "")
end

function enchanting.on_put(pos, listname, _, stack, player)
	if not enchanting.is_owner(pos, player) then
		minetest.chat_send_player(player:get_player_name(), "You are not the owner of this enchanting table")
		return
	end
	if listname == "tool" then
		local tools_cat = {
			["tool"] = {"pick", "axe", "shovel"},
			["armor"] = {"chestplate", "leggings", "helmet"},
			["sword"] = {"sword"}, ["boots"] = {"boots"} }

		for cat, name in pairs(tools_cat) do
		for _, n in pairs(name) do
			if stack:get_name():find(n) then
				enchanting.formspec(pos, cat)
			end
		end
		end
	end
end

function enchanting.fields(pos, _, fields)
	if fields.quit then return end
	local inv = minetest.get_meta(pos):get_inventory()
	local tool = inv:get_stack("tool", 1)
	local mese = inv:get_stack("mese", 1)
	local orig_wear = tool:get_wear()
	local mod, name = tool:get_name():match("([%w_]+):([%w_]+)")
	local enchanted_tool = mod..":enchanted_"..name.."_"..next(fields)

	if mese:get_count() > 0 and minetest.registered_tools[enchanted_tool] then
		tool:replace(enchanted_tool)
		tool:add_wear(orig_wear)
		mese:take_item()
		inv:set_stack("mese", 1, mese)
		inv:set_stack("tool", 1, tool)
	end
end

function enchanting.dig(pos, player)
	if not enchanting.is_owner(pos, player) then
		minetest.chat_send_player(player:get_player_name(), "You are not the owner of this enchanting table")
		return false
	end
	local inv = minetest.get_meta(pos):get_inventory()
	return inv:is_empty("tool") and inv:is_empty("mese")
end

local function allowed(tool)
	for item in pairs(minetest.registered_tools) do
		if item:match("enchanted_"..tool) then
			return true
		end
	end
	return false
end

function enchanting.put(pos, listname, _, stack, player)
	if not enchanting.is_owner(pos, player) then
		minetest.chat_send_player(player:get_player_name(), "You are not the owner of this enchanting table")
		return 0
	end
	local item = stack:get_name():match(":([%w_]+)")
	if listname == "mese" and item == "mese_crystal" then
		return stack:get_count()
	elseif listname == "tool" and allowed(item) then
		return 1 
	end

	return 0
end

function enchanting.on_take(pos, listname, _, _, player)
	if not enchanting.is_owner(pos, player) then
		minetest.chat_send_player(player:get_player_name(), "You are not the owner of this enchanting table")
		return
	end
	if listname == "tool" then
		enchanting.formspec(pos, nil)
	end
end

function enchanting.construct(pos)
	local meta = minetest.get_meta(pos)
	meta:set_string("infotext", "Enchantment Table")
	enchanting.formspec(pos, nil)

	local inv = meta:get_inventory()
	inv:set_size("tool", 1)
	inv:set_size("mese", 1)
end

xdecor.register("enchantment_table", {
	description = "Enchantment Table",
	tiles = {
		"xdecor_enchantment_top.png", "xdecor_enchantment_bottom.png",
		"xdecor_enchantment_side.png", "xdecor_enchantment_side.png",
		"xdecor_enchantment_side.png", "xdecor_enchantment_side.png"
	},
	groups = {cracky=1, oddly_breakable_by_hand=1, level=1},
	sounds = default.node_sound_stone_defaults(),
	on_rotate = screwdriver.rotate_simple,
	can_dig = enchanting.dig,
	on_construct = enchanting.construct,

	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
		meta:set_string("infotext", "Enchanting table (owned by " .. meta:get_string("owner") .. ")")
		-- we dont support member yet, meta:set_string("members", "")
		-- and this should only work with protection mod installed, since we use its own metadata format
	end,

	on_receive_fields = enchanting.fields,
	on_metadata_inventory_put = enchanting.on_put,
	on_metadata_inventory_take = enchanting.on_take,
	allow_metadata_inventory_put = enchanting.put,
	allow_metadata_inventory_move = function() return 0 end
})

local function cap(str)
	return str:gsub("^%l", string.upper)
end

 -- Higher number = stronger enchant.
local use_factor = 1.2
local times_subtractor = 0.1
local damage_adder = 1
local strength_factor = 1.2
local speed_factor = 0.2
local jump_factor = 0.2

local tools = {
	--[[ Registration format :
	 	[Mod name] = {
	 		{materials},
	 		{tool name, tool group, {enchantments}}
		 }
	--]]
	["default"] = {
		{"steel", "bronze", "mese", "diamond"},
		{"axe", "choppy", {"durable", "fast"}}, 
		{"pick", "cracky", {"durable", "fast"}}, 
		{"shovel", "crumbly", {"durable", "fast"}},
		{"sword", "fleshy", {"sharp"}}
	},
	["3d_armor"] = {
		{"steel", "bronze", "gold", "diamond"},
		{"boots", nil, {"strong", "speed"}},
		{"chestplate", nil, {"strong"}},
		{"helmet", nil, {"strong"}},
		{"leggings", nil, {"strong"}}
	}
}

for mod, defs in pairs(tools) do
for _, mat in pairs(defs[1]) do
for _, tooldef in next, defs, 1 do
for _, ench in pairs(tooldef[3]) do
	local tool, group, material, enchant = tooldef[1], tooldef[2], mat, ench
	local original_tool = minetest.registered_tools[mod..":"..tool.."_"..material]

	if original_tool then
		if mod == "default" then
			local original_damage_groups = original_tool.tool_capabilities.damage_groups
			local original_groupcaps = original_tool.tool_capabilities.groupcaps
			local groupcaps = table.copy(original_groupcaps)
			local fleshy = original_damage_groups.fleshy
			local full_punch_interval = original_tool.tool_capabilities.full_punch_interval
			local max_drop_level = original_tool.tool_capabilities.max_drop_level

			if enchant == "durable" then
				groupcaps[group].uses = math.ceil(original_groupcaps[group].uses * use_factor)
			elseif enchant == "fast" then
				for i = 1, 3 do
					groupcaps[group].times[i] = original_groupcaps[group].times[i] - times_subtractor
				end
			elseif enchant == "sharp" then
				fleshy = fleshy + damage_adder
			end

			minetest.register_tool(":"..mod..":enchanted_"..tool.."_"..material.."_"..enchant, {
				description = "Enchanted "..cap(material).." "..cap(tool).." ("..cap(enchant)..")",
				inventory_image = original_tool.inventory_image.."^[colorize:violet:50",
				wield_image = original_tool.wield_image,
				groups = {not_in_creative_inventory=1},
				tool_capabilities = {
					groupcaps = groupcaps, damage_groups = {fleshy = fleshy},
					full_punch_interval = full_punch_interval, max_drop_level = max_drop_level
				}
			})
		end

		if mod == "3d_armor" then
			local original_armor_groups = original_tool.groups
			local armorcaps = table.copy(original_armor_groups)
			local armorcaps = {}
			armorcaps.not_in_creative_inventory=1

			for armor_group, value in pairs(original_armor_groups) do
				if enchant == "strong" then
					armorcaps[armor_group] = math.ceil(value * strength_factor)
				elseif enchant == "speed" then
					armorcaps[armor_group] = value
					armorcaps.physics_speed = speed_factor
					armorcaps.physics_jump = jump_factor
				end
			end

			minetest.register_tool(":"..mod..":enchanted_"..tool.."_"..material.."_"..enchant, {
				description = "Enchanted "..cap(material).." "..cap(tool).." ("..cap(enchant)..")",
				inventory_image = original_tool.inventory_image,
				texture = "3d_armor_"..tool.."_"..material,
				wield_image = original_tool.wield_image,
				groups = armorcaps,
				wear = 0
			})
		end
	end
end
end
end
end

