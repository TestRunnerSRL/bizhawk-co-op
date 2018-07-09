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

local junkItems = {
[1]={['val']=0x28, ['name']='Three Bombs'},
	{['val']=0x34, ['name']='One Rupee'},
	{['val']=0x35, ['name']='Five Rupees'},
	{['val']=0x36, ['name']='Twenty Rupees'},
	{['val']=0x42, ['name']='Heart'},
	{['val']=0x45, ['name']='Small Magic'},
}


local gameLoadedModes = {
    [0x00]=false,  --Triforce / Zelda startup screens
    [0x01]=false,  --Game Select screen
    [0x02]=false,  --Copy Player Mode
    [0x03]=false,  --Erase Player Mode
    [0x04]=false,  --Name Player Mode
    [0x05]=false,  --Loading Game Mode
    [0x06]=true,  --Pre Dungeon Mode
    [0x07]=true,  --Dungeon Mode
    [0x08]=true,  --Pre Overworld Mode
    [0x09]=true,  --Overworld Mode
    [0x0A]=true,  --Pre Overworld Mode (special overworld)
    [0x0B]=true,  --Overworld Mode (special overworld)
    [0x0C]=true,  --???? I think we can declare this one unused, almost with complete certainty.
    [0x0D]=true,  --Blank Screen
    [0x0E]=true,  --Text Mode/Item Screen/Map
    [0x0F]=true,  --Closing Spotlight
    [0x10]=true,  --Opening Spotlight
    [0x11]=true,  --Happens when you fall into a hole from the OW.
    [0x12]=true,  --Death Mode
    [0x13]=true,  --Boss Victory Mode (refills stats)
    [0x14]=false,  --History Mode (Title Screen Demo)
    [0x15]=true,  --Module for Magic Mirror
    [0x16]=true,  --Module for refilling stats after boss.
    [0x17]=false,  --Restart mode (save and quit)
    [0x18]=true,  --Ganon exits from Agahnim's body. Chase Mode.
    [0x19]=true,  --Triforce Room scene
    [0x1A]=false,  --End sequence
    [0x1B]=false,  --Screen to select where to start from (House, sanctuary, etc.)
}


local deathQueue = {}
local function tableCount(table)
	local count = 0
    for _, _ in pairs(table) do
        count = count + 1
    end
    return count
end

local prevRAM = nil
local gameMode
local prevGameMode = nil

local gameLoaded
local prevGameLoaded = true
local dying = false
local prevmode = 0
local oot_rom = {}
local playercount = 1

-- Writes value to RAM using little endian
local prevDomain = ""
local function writeRAM(domain, address, size, value)
	-- update domain
	if (prevDomain ~= domain) then
		prevDomain = domain
		if not memory.usememorydomain(domain) then
			return
		end
	end

	-- default size short
	if (size == nil) then
		size = 2
	end

	if (value == nil) then
		return
	end

	if size == 1 then
		memory.writebyte(address, value)
	elseif size == 2 then
		memory.write_u16_be(address, value)
	elseif size == 4 then
		memory.write_u32_be(address, value)
	end
end

-- Reads a value from RAM using little endian
local function readRAM(domain, address, size)
	-- update domain
	if (prevDomain ~= domain) then
		prevDomain = domain
		if not memory.usememorydomain(domain) then
			return
		end
	end

	-- default size short
	if (size == nil) then
		size = 2
	end

	if size == 1 then
		return memory.readbyte(address)
	elseif size == 2 then
		return memory.read_u16_be(address)
	elseif size == 4 then
		return memory.read_u32_be(address)
	end
end


-- Return the new value only when changing from 0
local function zeroChange(newValue, prevValue) 
	if (newValue == 0 or (newValue ~= 0 and prevValue == 0)) then
		return newValue
	else
		return prevValue
	end
end

local function clamp(newValue, prevValue, address, item)
	if item.min then
		newValue = math.max(newValue, item.min)
	end
	if item.max then
		newValue = math.min(newValue, item.max)
	end
	return newValue
end


-- List of ram values to track
local ramItems = {

}


-- Display a message of the ram event
local function getGUImessage(address, prevVal, newVal, user)
	-- Only display the message if there is a name for the address
	local name = ramItems[address].name
	if name and prevVal ~= newVal then
		-- If boolean, show 'Removed' for false
		if ramItems[address].type == "bool" then				
			gui.addmessage(user .. ": " .. name .. (newVal == 0 and 'Removed' or ''))
		-- If numeric, show the indexed name or name with value
		elseif ramItems[address].type == "num" then
			if (type(name) == 'string') then
				gui.addmessage(user .. ": " .. name .. " = " .. newVal)
			elseif (name[newVal]) then
				gui.addmessage(user .. ": " .. name[newVal])
			end
		-- If bitflag, show each bit: the indexed name or bit index as a boolean
		elseif ramItems[address].type == "bit" then
			for b=0,7 do
				local newBit = bit.check(newVal, b)
				local prevBit = bit.check(prevVal, b)

				if (newBit ~= prevBit) then
					if (type(name) == 'string') then
						gui.addmessage(user .. ": " .. name .. " flag " .. b .. (newBit and '' or ' Removed'))
					elseif (name[b]) then
						gui.addmessage(user .. ": " .. name[b] .. (newBit and '' or ' Removed'))
					end
				end
			end
		-- if delta, show the indexed name, or the differential
		elseif ramItems[address].type == "delta" then
			local delta = newVal - prevVal
			if (delta > 0) then
				if (type(name) == 'string') then
					gui.addmessage(user .. ": " .. name .. (delta > 0 and " +" or " ") .. delta)
				elseif (name[newVal]) then
					gui.addmessage(user .. ": " .. name[newVal])
				end
			end
		elseif ramItems[address].type == "deltalist" then
			local index = -1
			for k,v in pairs(name) do
				if v.value == newVal then
					index = k
				end
			end

			if (name[index]) then
				gui.addmessage(user .. ": " .. name[index].name)
			end
		else 
			gui.addmessage("Unknown item ram type")
		end
	end
end


-- Get the list of ram values
local function getRAM() 
	newRAM = {}
	for address, item in pairs(ramItems) do
		-- Default byte length to 1
		if (not item.size) then
			item.size = 1
		end

		local ramval = readRAM("WRAM", address, item.size)

		-- Apply bit mask if it exist
		if (item.mask) then
			ramval = bit.band(ramval, item.mask)
		end

		newRAM[address] = ramval
	end

	return newRAM
end


-- Get a list of changed ram events
local function eventRAMchanges(prevRAM, newRAM)
	local ramevents = {}
	local changes = false

	for address, val in pairs(newRAM) do
		-- If change found
		if (prevRAM[address] ~= val) then
			getGUImessage(address, prevRAM[address], val, config.user)

			-- If boolean, get T/F
			if ramItems[address].type == "bool" then
				ramevents[address] = (val ~= 0)
				changes = true
			-- If numeric, get value
			elseif ramItems[address].type == "num" then
				ramevents[address] = val				
				changes = true
			-- If bitflag, get the changed bits
			elseif ramItems[address].type == "bit" then
				local changedBits = {}
				for b=0,7 do
					local newBit = bit.check(val, b)
					local prevBit = bit.check(prevRAM[address], b)

					if (newBit ~= prevBit) then
						changedBits[b] = newBit
					end
				end
				ramevents[address] = changedBits
				changes = true
			-- If delta, get the change from prevRAM frame
			elseif ramItems[address].type == "delta" then
				ramevents[address] = val - prevRAM[address]
				changes = true
			elseif ramItems[address].type == "listdelta" then
				local prevIndex = -1
				local newIndex = -1
				for k,v in pairs(ramItems[address].name) do
					if v.value == val then
						newIndex = k
					end
					if v.value == prevRAM[address] then
						prevIndex = k
					end
				end

				if (prevIndex == -1 or newIndex == -1) then
					printOutput("Unknown ram list index value")
				else
					remevents[address] = newIndex - prevIndex
				end
			else 
				printOutput("Unknown item ram type")
			end
		end
	end

	if (changes) then
		return ramevents
	else
		return false
	end
end


-- set a list of ram events
local function setRAMchanges(prevRAM, their_user, newEvents)
	for address, val in pairs(newEvents) do
		local newval

		-- If boolean type value
		if ramItems[address].type == "bool" then
			newval = (val and 1 or 0)
		-- If numeric type value
		elseif ramItems[address].type == "num" then
			newval = val
		-- If bitflag update each bit
		elseif ramItems[address].type == "bit" then
			newval = prevRAM[address]
			for b, bitval in pairs(val) do
				if bitval then
					newval = bit.set(newval, b)
				else
					newval = bit.clear(newval, b)
				end
			end
		-- If delta, add to the previous value
		elseif ramItems[address].type == "delta" then
			newval = prevRAM[address] + val
		elseif ramItems[address].type == "listdelta" then
			local prevIndex = -1
			for k,v in pairs(ramItems[address].name) do
				if v.value == prevRAM[address] then
					prevIndex = k
				end
			end
			local newIndex = prevIndex + val
			if (prevIndex == -1 or newIndex == -1 or ramItems[address].name[newIndex] == nil) then
				printOutput("Unknown ram list index value")
				newval = prevRAM[address]
			else
				newval = ramItems[address].list[newIndex]
			end			
		else 
			printOutput("Unknown item ram type")
			newval = prevRAM[address]
		end

		-- Run the address's reveive function if it exists
		if (ramItems[address].receiveFunc) then
			newval = ramItems[address].receiveFunc(newval, prevRAM[address], address, ramItems[address], their_user)
		end

		-- Apply the address's bit mask
		if (ramItems[address].mask) then
			local xMask = bit.bxor(ramItems[address].mask, 0xFF)
			local prevval = readRAM("WRAM", address, ramItems[address].size)

			prevval = bit.band(prevval, xMask)
			newval = bit.band(newval, ramItems[address].mask)
			newval = bit.bor(prevval, newval)
		end

		-- Write the new value
		getGUImessage(address, prevRAM[address], newval, their_user)
		prevRAM[address] = newval
		if gameLoadedModes[gameMode] then
			writeRAM("WRAM", address, ramItems[address].size, newval)
		end
	end	
	return prevRAM
end



-- Get item override table
local locations = {}
local override_table = memory.read_s32_be(0xD278, "ROM") + 0x1000
while memory.read_s32_be(override_table, "ROM") ~= 0 do
	table.insert(locations, {
		["address"] = override_table + 3
	})
	override_table = override_table + 4;
end


local splitItems = {}
local function removeItems()
	-- Reload Core to restore previously removed items
	client.reboot_core()
	prevDomain = ""

	local junkItemsCount = tableCount(junkItems)
	math.randomseed(os.time())
	math.random(junkItemsCount)

	for ID, location in pairs(locations) do
		-- Remove item if it's not yours
		if (splitItems[ID] ~= my_ID) then
			local oldVal = readRAM("CARTROM", location.address, 1)
			-- Remove Item, Fill with junk
			writeRAM("CARTROM", location.address, 1, junkItems[math.random(junkItemsCount)].val)
		end
	end
end

client.reboot_core()
prevDomain = ""


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


-- Gets a message to send to the other player of new changes
-- Returns the message as a dictionary object
-- Returns false if no message is to be send
function oot_rom.getMessage()
	-- Check if game is playing
	gameMode = readRAM("WRAM", 0x0010, 1)
	local gameLoaded = gameLoadedModes[gameMode] == true

	-- Don't check for updated when game is not running
	if not gameLoaded then
		prevGameMode = gameMode
		return false
	end

	-- Initilize previous RAM frame if missing
	if prevRAM == nil then
		prevRAM = getRAM()
	end

	-- Checked for queued death and apply when safe
	if tableCount(deathQueue) > 0 and not deathQueue[config.user] then
		-- Main mode: 07 = Dungeon, 09 = Overworld, 0B = Special Overworld
		-- Sub mode: Non 0 = game is paused, transitioning between modes
		if (gameMode == 0x07 or gameMode == 0x09 or gameMode == 0x0B) and (readRAM("WRAM", 0x0011, 1) == 0x00) then 
			-- If link is controllable
			writeRAM("WRAM", 0x0010, 2, 0x0012) -- Kill link as soon as it's safe
			writeRAM("WRAM", 0xF36D, 1, 0)
			writeRAM("WRAM", 0x04C6, 1, 0) -- Stop any special cutscenes
			prevRAM[0xF36D] = 0
			gameMode = 0x12
		end
	end

	if gameMode == 0x12 then
		local deathCount = tableCount(deathQueue)
		if (deathCount > 0 and deathCount < playercount) then
			-- Lock the death until everyone is dying
			writeRAM("WRAM", 0x0010, 2, 0x0012)
		elseif (deathCount >= playercount) then
			deathQueue = {}

			local hasFairy = false
			for bottleID=0,3 do
				if prevRAM[0xF35C + bottleID] == 0x06 then
					-- has fairy
					hasFairy = true
				end
			end

			local maxHP = readRAM("WRAM", 0xF36C, 1)
			local contHP
			if (hasFairy) then
				contHP = 7 * 8
			else
			 	contHP = (continueHP[maxHP / 8] or 10) * 8
			end
			prevRAM[0xF36D] = math.max(math.min(prevRAM[0xF36D] + contHP, maxHP), 0)
			writeRAM("WRAM", 0xF36D, 1, prevRAM[0xF36D])		
		end

		if (prevGameMode == 0x12) then
			-- discard continue HP/fairy HP
			writeRAM("WRAM", 0xF36D, 1, prevRAM[0xF36D])
		end
	end

	-- Game was just loaded, restore to previous known RAM state
	if (gameLoaded and not gameLoadedModes[prevGameMode]) then
		 -- get changes to prevRAM and apply them to game RAM
		local newRAM = getRAM()
		local message = eventRAMchanges(newRAM, prevRAM)
		prevRAM = newRAM
		if (message) then
			oot_rom.processMessage("Save Restore", message)
		end
	end

	-- Load all queued changes
	while not messageQueue.isEmpty() do
		local nextmessage = messageQueue.popLeft()
		oot_rom.processMessage(nextmessage.their_user, nextmessage.message)
	end

	-- Get current RAM events
	local newRAM = getRAM()
	local message = eventRAMchanges(prevRAM, newRAM)

	-- Update the RAM frame pointer
	prevRAM = newRAM

	-- Check for death message
	if gameMode == 0x12 then
		if (prevGameMode ~= 0x12) then
			if message == false then
				message = {}
			end

			message[0xF36D] = -0x100 -- death message is a large HP loss
			deathQueue[config.user] = true
		else 
			-- suppress all non death messages during death sequence
			return false
		end
	end
	prevGameMode = gameMode

	return message
end


-- Process a message from another player and update RAM
function oot_rom.processMessage(their_user, message)
	if message["i"] then
		splitItems = message["i"]
		message["i"] = nil
		removeItems()

		local playerlist = {}
		playercount = 0
		for _,player in pairs(splitItems) do
			if playerlist[player] == nil then
				playerlist[player] = true
				playercount = playercount + 1
			end
		end
	end

	if gameLoadedModes[gameMode] then
		prevRAM = setRAMchanges(prevRAM, their_user, message)
	else
		messageQueue.pushRight({["their_user"]=their_user, ["message"]=message})
	end
end

setmetatable(_G, old_global_metatable)

return oot_rom
