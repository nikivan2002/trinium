local player_to_id_text = {} -- Storage of players so the mod knows what huds to update
local player_to_id_mtext = {}
local player_to_id_image = {}
local player_to_id_current_item = {}
local player_to_cnode = {} -- Get the current looked at node
local player_to_cwield = {} -- Get the current looked at node
local player_to_animtime = {} -- For animation
local player_to_animon = {} -- For disabling animation
local player_to_enabled = {} -- For disabling WiTT
local player_to_fluid_enabled = {}

local S = trinium.S

local ypos = 0.1

local function get_looking_node(player)
    local lookat
    for i = 0, 50 do
        local lookvector = -- This variable will store what node we might be looking at
            vector.add( -- This add function corrects for the players approximate height
                vector.add( -- This add function applies the camera's position to the look vector
                    vector.multiply( -- This multiply function adjusts the distance from the camera by the iteration of the loop we're in
                        player:get_look_dir(), 
                        i/10 -- Goes from 0 to 5 with step of 1/10
                    ), 
                    player:get_pos()
                ),
                vector.new(0, 1.5, 0)
            )
        lookat = minetest.get_node_or_nil( -- This actually gets the node we might be looking at
            lookvector
        ) or lookat
        if lookat ~= nil and -- node is loaded,
			lookat.name ~= "air" and -- not air
			minetest.registered_nodes[lookat.name] and -- and known (cuz this one was always broken in WITT)
			(player_to_fluid_enabled[player] or
				not minetest.registered_nodes[lookat.name].liquidtype or 
				minetest.registered_nodes[lookat.name].liquidtype == "none"
			) -- either player has fluids enabled or it is not fluid
		then break else
			lookat = nil
		end
    end
    return lookat
end

local function describe_node(node)
    local mod, nodename = minetest.registered_nodes[node.name].mod_origin, minetest.registered_nodes[node.name].description
    if nodename == "" then
        nodename = node.name
    end
    -- mod = trinium.adequate_text(mod)
	mod = trinium.adequate_text2(mod)
    -- nodename = trinium.adequate_text(nodename)
	nodename = nodename:split("\n")[1]
    return nodename, mod
end

local function handle_tiles(node)
    local tiles = node.tiles

    if tiles then
        for i,v in pairs(tiles) do
            if type(v) == "table" then
                if tiles[i].name then
                    tiles[i] = tiles[i].name
                else
                    return ""
                end
            end
        end

        if node.drawtype == "normal" or node.drawtype == "allfaces" or node.drawtype == "allfaces_optional" or node.drawtype == "glasslike" or node.drawtype == "glasslike_framed" or node.drawtype == "glasslike_framed_optional" then
            if #tiles == 1 then -- Whole block
                return minetest.inventorycube(tiles[1], tiles[1], tiles[1])
			elseif #tiles == 2 then -- Top differs
                return minetest.inventorycube(tiles[1], tiles[2], tiles[2])
            elseif #tiles == 3 then -- Top and Bottom differ
                return minetest.inventorycube(tiles[1], tiles[3], tiles[3])
            elseif #tiles == 6 then -- All sides
                return minetest.inventorycube(tiles[1], tiles[6], tiles[5])
            end
        end
    end

    return ""
end

local function update_player_hud_pos(player, to_x, to_y)
	to_y = to_y or ypos
	player:hud_change(player_to_id_text[player], "position", {x = to_x, y = to_y})
	player:hud_change(player_to_id_image[player], "position", {x = to_x, y = to_y})
	player:hud_change(player_to_id_mtext[player], "position", {x = to_x, y = to_y+0.015})
end

local function blank_player_hud(player) -- Make hud appear blank
	player:hud_change(player_to_id_text[player], "text", "")
	player:hud_change(player_to_id_mtext[player], "text", "")
	player:hud_change(player_to_id_image[player], "text", "")
end

minetest.register_globalstep(function(dtime) -- This will run every tick, so around 20 times/second
    for _, player in ipairs(minetest:get_connected_players()) do -- Do everything below for each player in-game
        if player_to_enabled[player] == nil then player_to_enabled[player] = true end -- Enable by default
        if player_to_fluid_enabled[player] == nil then player_to_fluid_enabled[player] = false end
        if not player_to_enabled[player] then return end -- Don't do anything if they have it disabled
        local lookat = get_looking_node(player) -- Get the node they're looking at

        player_to_animtime[player] = math.min((player_to_animtime[player] or 0.4) + dtime, 0.5) -- Animation calculation

        if player_to_animon[player] then -- If they have animation on, display it
            update_player_hud_pos(player, player_to_animtime[player])
        end

        if lookat then 
            if player_to_cnode[player] ~= lookat.name then -- Only do anything if they are looking at a different type of block than before
                player_to_animtime[player] = nil -- Reset the animation
                local nodename, mod = describe_node(lookat) -- Get the details of the block in a nice looking way
                player:hud_change(player_to_id_text[player], "text", nodename) -- If they are looking at something, display that
                player:hud_change(player_to_id_mtext[player], "text", mod)
                local node_object = minetest.registered_nodes[lookat.name] -- Get information about the block
                player:hud_change(player_to_id_image[player], "text", handle_tiles(node_object)) -- Pass it to handle_tiles which will return a texture of that block (or nothing if it can't create it)
            end
            player_to_cnode[player] = lookat.name -- Update the current node
        else
            blank_player_hud(player) -- If they are not looking at anything, do not display the text
            player_to_cnode[player] = nil -- Update the current node
        end
		
		local stack = player:get_wielded_item()
		if stack:get_name() ~= player_to_cwield[player] then
			if stack:is_empty() then
				player:hud_change(player_to_id_current_item[player], "text", "")
			elseif not stack:is_known() then
				player:hud_change(player_to_id_current_item[player], "text", S"info.unknown")
			else
				player:hud_change(player_to_id_current_item[player], "text", minetest.registered_items[stack:get_name()].description:split("\n")[1] or "???")
			end
			player_to_cwield[player] = stack:get_name()
		end
    end
end)

minetest.register_on_joinplayer(function(player) -- Add the hud to all players
    player_to_id_text[player] = player:hud_add({ -- Add the block name text
        hud_elem_type = "text",
        text = "test",
        number = 0xffffff,
        alignment = {x = 1, y = 0},
        position = {x = 0.5, y = ypos},
    })
    player_to_id_mtext[player] = player:hud_add({ -- Add the mod name text
        hud_elem_type = "text",
        text = "test",
        number = 0x2d62b7,
        alignment = {x = 1, y = 0},
        position = {x = 0.5, y = ypos+0.015},
    })
    player_to_id_image[player] = player:hud_add({ -- Add the block image
        hud_elem_type = "image",
        text = "",
        scale = {x = 1, y = 1},
        alignment = 0,
        position = {x = 0.5, y = ypos},        
        offset = {x = -40, y = 0}
    })
    player_to_id_current_item[player] = player:hud_add({ -- Add the wielded item
        hud_elem_type = "text",
        text = "",
        number = 0xffffff,
        alignment = {x = 0, y = 0},
        position = {x = 0.5, y = 0.9},
    })
end)

minetest.register_chatcommand("wanim", {
	params = "<on/off>",
	description = "Turn WiTT animations on/off",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false end
        player_to_animon[player] = param == "on"
        return true
	end
})

minetest.register_chatcommand("witt", {
	params = "<on/off>",
	description = "Turn WiTT on/off",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false end
        player_to_enabled[player] = param == "on"
        blank_player_hud(player)
        player_to_cnode[player] = nil
        return true
	end
})

minetest.register_chatcommand("wittfluid", {
	params = "<on/off>",
	description = "Turn WiTT fluids on/off",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false end
        player_to_fluid_enabled[player] = param == "on"
        blank_player_hud(player)
        player_to_cnode[player] = nil
        return true
	end
})