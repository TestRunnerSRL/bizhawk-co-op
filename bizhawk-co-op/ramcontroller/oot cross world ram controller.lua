
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
	mainmemory.write_u8(0x402014, 0x7F)

	local scene = oot.ctx:rawget('cur_scene'):rawget()

	mainmemory.write_u8(override_table_end + 0, scene)
	mainmemory.write_u8(override_table_end + 1, bit.lshift(player_num, 3))
	mainmemory.write_u8(override_table_end + 2, 0x7F)
	mainmemory.write_u8(override_table_end + 3, id)
end


oot_rom.itemcount = 1



local messageQueue = {first = 0, last = -1}
function messageQueue.isEmpty()
	return messageQueue.first > messageQueue.last
end
function messageQueue.pushLeft (value)
  local first = messageQueue.first - 1
  messageQueue.first = first
  messageQueue[first] = value
end
function messageQueue.pushRight (value)
  local last = messageQueue.last + 1
  messageQueue.last = last
  messageQueue[last] = value
end
function messageQueue.popLeft ()
  local first = messageQueue.first
  if messageQueue.isEmpty() then error("list is empty") end
  local value = messageQueue[first]
  messageQueue[first] = nil        -- to allow garbage collection
  messageQueue.first = first + 1
  return value
end
function messageQueue.popRight ()
  local last = messageQueue.last
  if messageQueue.isEmpty() then error("list is empty") end
  local value = messageQueue[last]
  messageQueue[last] = nil         -- to allow garbage collection
  messageQueue.last = last - 1
  return value
end


local function safeToGiveItem()
	local details
	_, details = oot.get_current_game_mode()
	return details.name == "Normal Gameplay"
end

local function processQueue()

	local pending_item = mainmemory.read_u8(0x402014)
	if safeToGiveItem() and not messageQueue.isEmpty() and pending_item == 0 then
		-- pop from the queue and give the item
		local item = messageQueue.popLeft()
		get_item(item)
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
		message = {m = { p = player, i = item } }
		-- clear the pending item
		mainmemory.write_u32_be(0x402000, 0)
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
			messageQueue.pushRight(message["m"].i)
		end
	end

end


setmetatable(_G, old_global_metatable)

return oot_rom
