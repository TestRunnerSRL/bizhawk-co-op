
console.log('------------------')
local old_global_metatable = getmetatable(_G)
setmetatable(_G, {
	__newindex = function (_, n)
		error("Created global variable \""..n.."\".\nDidn't you want this to be local?\nIf you actually wanted a global variable,\nuse the \"declare\" function instead.", 2)
	end,
})
local function declare (name, initval)
	rawset(_G, name, initval or false)
end

local oot = require('bizhawk-co-op\\helpers\\oot')

local oot_rom = {}

-- get your player num
local player_num = mainmemory.read_u8(0x401C00)

-- gives an item
local get_item = function(item)
	if (item.i == 0) then
		-- Trying to place padded items
		printOutput("[Warn] Attempting to give invalid item!")

		-- Don't give the item but increment the internal_count
		local internal_count = mainmemory.read_u16_be(0x11A660)
		internal_count = internal_count + 1
		mainmemory.write_u16_be(0x11A660, internal_count)
		return
	end

	mainmemory.write_u8(0x402018, 0x7F)   -- 7F is the coop item ID
	mainmemory.write_u8(0x401C01, item.i) -- this is the actual item to give
end


oot_rom.itemcount = 1

local sent_items = {}
local received_items = { [0] = {f = player_num, t = 0, k = 0, i = 0} }
local received_counter = 0
local send_player_name = false


local save_entry = function(key, value)
	if value.i == 0 then
		return
	end

	-- open file
	local file_loc = '.\\bizhawk-co-op\\savedata\\' .. gameinfo.getromname() .. '.dat'
	local f = io.open(file_loc, "a")

	if f then
		f:write(key .. ',' .. tabletostring(value) .. '\n')
		f:close()
	end
end


local load_save = function()
	-- open file
	local file_loc = '.\\bizhawk-co-op\\savedata\\' .. gameinfo.getromname() .. '.dat'
	local f = io.open(file_loc, "r")

	if f then
		sent_items = {}
		received_items = { [0] = {f = player_num, t = 0, k = 0, i = 0} }
		received_counter = 0

		for line in f:lines() do
			local splitline = strsplit(line, ',', 1)
			local key = splitline[1]
			local splitvalue = strsplit(splitline[2], ',')
			local value = stringtotable(splitvalue)

			if key == "sent" then
				table.insert(sent_items, value)
			elseif key == "received" then
				table.insert(received_items, value)
				received_counter = received_counter + 1
			end
		end
		f:close()
	end
end


local shop_scenes = {[0x2C]=1, [0x2D]=1, [0x2E]=1, [0x2F]=1, [0x30]=1, [0x31]=1, [0x32]=1, [0x33]=1, [0x42]=1, [0x4B]=1}
local function safeToGiveItem()
	local details
	local scene
	_, details = oot.get_current_game_mode()
	scene = oot.ctx:rawget('cur_scene'):rawget()
	return details.name == "Normal Gameplay" and shop_scenes[scene] == nil
end

local function processQueue()

	local pending_item = mainmemory.read_u8(0x402018)
	if safeToGiveItem() and pending_item == 0 then
		local internal_count = mainmemory.read_u16_be(0x11A660)
		-- fill the queue to the current counter
		while received_counter < internal_count do
			pad_item = {f = player_num, t = 0, k = 0, i = 0}
			table.insert(received_items, pad_item)
			received_counter = received_counter + 1
			save_entry("received", pad_item)
			printOutput("[Warn] Game has more items than in Script's Cache.")
		end
		-- if the internal counter is behind, give the next item
		if received_counter > internal_count then
			local item = received_items[internal_count + 1]
			get_item(item)
		end
	end
end


local table_has_key = function(table, key)
	for _,item in pairs(table) do
		local found = true
		for k,v in pairs(item) do
			if v ~= key[k] then
				found = false
			end
		end
		if found then
			return true
		end
	end
	return false
end


-- Gets a message to send to the other player of new changes
-- Returns the message as a dictionary object
-- Returns false if no message is to be send
function oot_rom.getMessage()
	local message = false

	-- runs every frame
	processQueue()

	-- if there is a item pending to give to another player, make a message for it and clear it
	local pending_item = mainmemory.read_u8(0x402001)
	if pending_item ~= 0 then
		-- create the message
		local player = mainmemory.read_u8(0x402002)
		local item = mainmemory.read_u8(0x402003)
		local key = mainmemory.read_u32_be(0x402004)

		message = {m = { f = player_num, t = player, k = key, i = item } }
		if not table_has_key(sent_items, message.m) then
			table.insert(sent_items, message.m)
			save_entry("sent", message.m)
		end

		-- clear the pending item data
		mainmemory.write_u32_be(0x402000, 0)
		mainmemory.write_u32_be(0x402004, 0)
	end

	if send_player_name then
		send_player_name = false

		if not message then
			message = {}
		end

		message["n"] = player_num
	end

	return message
end


local write_name = function(name, id)
	local name_address = 0x401C03 + (id * 8)
	local name_index = 0

	for _,c in pairs({string.byte(name, 1, 100)}) do
		if c >= string.byte('0') and c <= string.byte('9') then
			c = c - string.byte('0')
		elseif c >= string.byte('A') and c <= string.byte('Z') then
			c = c + 0x6A
		elseif c >= string.byte('a') and c <= string.byte('z') then
			c = c + 0x64
		elseif c == string.byte('.') then
			c = 0xEA
		elseif c == string.byte('-') then
			c = 0xE4
		elseif c == string.byte(' ') then
			c = 0xDF
		else
			c = nil
		end

		if c ~= nil then
			mainmemory.write_u8(name_address + name_index, c)

			name_index = name_index + 1
			if name_index >= 8 then
				break
			end
		end	
	end

	for i = name_index, 7 do
		mainmemory.write_u8(name_address + i, 0xDF)
	end
end


-- Process a message from another player and update RAM
function oot_rom.processMessage(their_user, message)
	if message["i"] then
		write_name(config.user, player_num)
		send_player_name = true
		load_save()
	end

	if message["n"] then
		write_name(their_user, message["n"])
	end

	if message["m"] then
		-- check if this is for this player, otherwise, ignore it
		if message["m"].t == player_num then
			-- Check if this item has been received already
			if not table_has_key(received_items, message["m"]) then
				-- queue up the item get
				table.insert(received_items, message["m"])
				received_counter = received_counter + 1
				save_entry("received", message["m"])
			end
		end
	end
end


setmetatable(_G, old_global_metatable)

return oot_rom
