
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

local playercount = 1

-- get the end of the override table
local override_table_end = 0x401000
while mainmemory.read_u32_be(override_table_end) ~= 0 do
	override_table_end = override_table_end + 4
end

-- get your player num
local player_num = mainmemory.read_u8(0x401C00)

-- gives an item
local get_item = function(id)
	mainmemory.write_u8(0x402018, 0x7F)

	local scene = oot.ctx:rawget('cur_scene'):rawget()

	mainmemory.write_u8(override_table_end + 0, scene)
	mainmemory.write_u8(override_table_end + 1, bit.lshift(player_num, 3))
	mainmemory.write_u8(override_table_end + 2, 0x7F)
	mainmemory.write_u8(override_table_end + 3, id)
end


oot_rom.itemcount = 1

local sent_items = {}
local received_items = { [0] = 0 }
local received_counter = 0


local shop_scenes = {[0x2C]=1, [0x2D]=1, [0x2E]=1, [0x2F]=1, [0x30]=1, [0x31]=1, [0x32]=1, [0x33]=1}
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
			table.insert(received_items, 0)
			received_counter = received_counter + 1
		end
		-- if the internal counter is behind, give the next item
		if received_counter > internal_count then
			local item = received_items[internal_count + 1]
			get_item(item)
		end
	end
end


-- Gets a message to send to the other player of new changes
-- Returns the message as a dictionary object
-- Returns false if no message is to be send
function oot_rom.getMessage()
	message = false

	-- runs every frame
	local scene = oot.ctx:rawget('cur_scene'):rawget()
	mainmemory.write_u8(override_table_end + 0, scene)
	processQueue()

	-- if there is a item pending to give to another player, make a message for it and clear it
	local pending_item = mainmemory.read_u8(0x402001)
	if pending_item ~= 0 then
		-- create the message
		local player = mainmemory.read_u8(0x402002)
		local item = mainmemory.read_u8(0x402003)
		local key = mainmemory.read_u32_be(0x402004)
		if not sent_items[key] then
			message = {m = { p = player, i = item } }
			sent_items[key] = true
		end
		-- clear the pending item data
		mainmemory.write_u32_be(0x402000, 0)
		mainmemory.write_u32_be(0x402004, 0)
	end

	return message
end


-- Process a message from another player and update RAM
function oot_rom.processMessage(their_user, message)
	if message["i"] then
		-- do literally nothing
	end

	if message["m"] then
		-- check if this is for this player, otherwise, ignore it
		if message["m"].p == player_num then
			-- queue up the item get
			table.insert(received_items, message["m"].i)
			received_counter = received_counter + 1
		end
	end

end


setmetatable(_G, old_global_metatable)

return oot_rom
