-- Mapping for the flags of each ability (little endian)
local AbilityMap = {
	--longbeam = 0
	0x00000101, 	
	--icebeam = 1
	0x00000202,
	--wavebeam = 2
	0x00000404,
	--plasmabeam = 3
	0x00000008,
	--chargebeam = 4
	0x00001010,
	--bombs = 5
	0x00008080,

	--hijump = 6
	0x01010000,
	--speedbooster = 7
	0x02020000,
	--spacejump = 8
	0x00040000,
	--screwattack = 9
	0x08080000,
	--variasuit = 10
	0x10100000,
	--gravitysuit = 11
	0x00200000,
	--morphball = 12
	0x40400000,
	--powergrip = 13
	0x80800000
}


-- Writes value to RAM using little endian
local prevDomain = ""
function writeRAM(domain, address, size, value)
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
		memory.write_u16_le(address, value)
	elseif size == 4 then
		memory.write_u32_le(address, value)
	end
end

-- Reads a value from RAM using little endian
function readRAM(domain, address, size)
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
		return memory.read_u16_le(address)
	elseif size == 4 then
		return memory.read_u32_le(address)
	end
end



-- Gets the list of the abilities in RAM
function getAbility()
	local ability = {}
	flags = readRAM("IWRAM", 0x153C, 4)

	for abilityNum, value in pairs(AbilityMap) do
		-- if ability flags found add ability
		if (bit.band(flags, value) > 0) then
			ability[abilityNum] = true
		end
	end
	return ability
end

-- Gets the list of all the event states
function getEvents()
	local events = {}
	for i=0,11 do
		local eventbyte = readRAM("EWRAM", 0x037E00 + i, 1)
		for j=0,7 do
			-- set event number true if bit is set, otherwise false
			events[j + i*8] = (bit.band(eventbyte, 0x01) > 0)
			eventbyte = bit.rshift(eventbyte, 1)
		end
	end
	return events
end

-- Gets the list of ammo values and capacities
function getAmmo()
	return {
		energyCapacity = readRAM("IWRAM", 0x1530, 2),
		missileCapacity = readRAM("IWRAM", 0x1532, 2),
		superCapacity = readRAM("IWRAM", 0x1534, 1),
		powerCapacity = readRAM("IWRAM", 0x1535, 1),

		energyCount = readRAM("IWRAM", 0x1536, 2),
		missileCount = readRAM("IWRAM", 0x1538, 2),
		superCount = readRAM("IWRAM", 0x153A, 1),
		powerCount = readRAM("IWRAM", 0x153B, 1)
	}
end


-- Event to check if a new tank is collected
-- Reverts changes if the tank has been collected already
-- Does not send ammo updates if new tank is found
local prevCollectingTankFlag = 0
function eventTankCollected(prevRam, newRam)
	local collectingTankFlag = readRAM("IWRAM", 0x0044, 1)
	if prevCollectingTankFlag ~= collectingTankFlag then
		prevCollectingTankFlag = collectingTankFlag
		if collectingTankFlag == 1 then
			-- If a tank is collected
			local newTank = {
				tankType = readRAM("IWRAM", 0x56A8, 1) - 0x38,
				areaID = readRAM("IWRAM", 0x0054, 1),
				roomID = readRAM("IWRAM", 0x0055, 1),
				tankX = readRAM("IWRAM", 0x56AA, 1),
				tankY = readRAM("IWRAM", 0x56AB, 1)
			}

			-- Check if it's a new tank
			for i, tank in pairs(prevRam.tanks) do
				local match = true
				for k,v in pairs(tank) do
					if (newTank[k] ~= v) then
						match = false
						break
					end
				end

				if match then
					-- If tank was alread collected then revert changes
					for ammo,value in pairs(prevRam.ammo) do
						newRam.ammo[ammo] = value
					end

					-- Update RAM to previous values
					writeRAM("IWRAM", 0x1530, 2, newRam.ammo.energyCapacity)
					writeRAM("IWRAM", 0x1532, 2, newRam.ammo.missileCapacity)
					writeRAM("IWRAM", 0x1534, 1, newRam.ammo.superCapacity)
					writeRAM("IWRAM", 0x1535, 1, newRam.ammo.powerCapacity)
					writeRAM("IWRAM", 0x1536, 2, newRam.ammo.energyCount)
					writeRAM("IWRAM", 0x1538, 2, newRam.ammo.missileCount)
					writeRAM("IWRAM", 0x153A, 1, newRam.ammo.superCount)
					writeRAM("IWRAM", 0x153B, 1, newRam.ammo.powerCount)

					return false, prevRam, newRam
				end
			end

			-- If it's a new tank then don't send new ammo updates
			for ammo,value in pairs(newRam.ammo) do
				prevRam.ammo[ammo] = value
			end

			-- Add tank to list of tanks
			table.insert(newRam.tanks, newTank)
			return newTank, prevRam, newRam
		end
	end
	-- No tank was collected
	return false, prevRam, newRam
end

-- Event to check when a new ability is collected
function eventAbilityCollected(prevRam, newRam)
	-- Find changed ability
	-- Only one ability can be collected at a time
	-- Only checks for added abilities, not removed (varia)
	local abilityNum = -1
	for ability,_ in pairs(newRam.ability) do
		if (prevRam.ability[ability] == nil) then
			abilityNum = ability
			break
		end
	end
	
	if abilityNum ~= -1 then
		-- Return the new ability
		return {
			ability = abilityNum,
			areaID = readRAM("IWRAM", 0x0054, 1),
			roomID = readRAM("IWRAM", 0x0055, 1),
			minimapX = readRAM("IWRAM", 0x0059, 1),
			minimapY = readRAM("IWRAM", 0x005A, 1)
		}
	end
	-- No new ability
	return false
end

-- Event to check if any game events have changed
function eventTriggerEvent(prevRam, newRam)
	local events = {}
	local changed = false

	-- check if any changes
	for i=0,95 do
		if (prevRam.events[i] ~= newRam.events[i]) then
			if newRam.events[i] then
				events[i] = true
			else
				events[i] = false
			end
			changed = true
		end
	end

	if changed then
		-- return list of changes
		return events
	else 
		-- no events changed
		return false
	end
end

-- Event to check if any ammo changed
-- Will not have any changes if a tank was collected
function eventAmmoChange(prevRam, newRam)
	local deltaammo = {}
	local changed = false

	if (prevRam.ammo.energyCount > 0) then
		-- If alive, send delta changes. Don't check for capacities (handled in tank event)
		deltaammo.delta = true

		-- Check energy count changes
		if (newRam.ammo.energyCount ~= prevRam.ammo.energyCount) then
			deltaammo.energyCount = newRam.ammo.energyCount - prevRam.ammo.energyCount
			changed = true			
		end
		-- Check missile count changes
		if (newRam.ammo.missileCount ~= prevRam.ammo.missileCount) then
			deltaammo.missileCount = newRam.ammo.missileCount - prevRam.ammo.missileCount
			changed = true			
		end
		-- Check super missile count changes
		if (newRam.ammo.superCount ~= prevRam.ammo.superCount) then
			deltaammo.superCount = newRam.ammo.superCount - prevRam.ammo.superCount
			changed = true			
		end
		-- Check power bomb count changes
		if (newRam.ammo.powerCount ~= prevRam.ammo.powerCount) then
			deltaammo.powerCount = newRam.ammo.powerCount - prevRam.ammo.powerCount
			changed = true			
		end
	else 
		-- Was dead, send override values. Check counts AND capacities
		deltaammo.delta = false
		for ammo, value in pairs(newRam.ammo) do
			if (prevRam.ammo[ammo] ~= value) then
				deltaammo[ammo] = value
				changed = true			
			end
		end		
	end

	if changed then
		-- return any changes
		return deltaammo
	else 
		-- ammo is unchanged
		return false
	end
end


-- This sets a tank to be collected and give the appropriate ammo
-- Does not trigger for tanks that have already been collected
function setTankCollected(prevRAM, newTank)
	-- Check if tank was already collected
	for i, tank in pairs(prevRAM.tanks) do
		local match = true
		for k,v in pairs(tank) do
			if (newTank[k] ~= v) then
				match = false
				break
			end
		end

		if match then
			-- If old tank, then do nothing
			return prevRAM
		end
	end

	-- New tank found
	table.insert(prevRAM.tanks, newTank)

	-- Update ammo for new tank
	if (newTank.tankType == 0) then
		prevRAM.ammo.energyCapacity = prevRAM.ammo.energyCapacity + 100
		writeRAM("IWRAM", 0x1530, 2, prevRAM.ammo.energyCapacity)
		prevRAM.ammo.energyCount = prevRAM.ammo.energyCapacity
		writeRAM("IWRAM", 0x1536, 2, prevRAM.ammo.energyCapacity)
	elseif (newTank.tankType == 1) then
		prevRAM.ammo.missileCapacity = prevRAM.ammo.missileCapacity + 5
		writeRAM("IWRAM", 0x1532, 2, prevRAM.ammo.missileCapacity)
		prevRAM.ammo.missileCount = prevRAM.ammo.missileCount + 5
		writeRAM("IWRAM", 0x1538, 2, prevRAM.ammo.missileCount)
	elseif (newTank.tankType == 2) then
		prevRAM.ammo.superCapacity = prevRAM.ammo.superCapacity + 5
		writeRAM("IWRAM", 0x1534, 1, prevRAM.ammo.superCapacity)
		prevRAM.ammo.superCount = prevRAM.ammo.superCount + 5
		writeRAM("IWRAM", 0x153A, 1, prevRAM.ammo.superCount)
	elseif (newTank.tankType == 3) then
		prevRAM.ammo.powerCapacity = prevRAM.ammo.powerCapacity + 5
		writeRAM("IWRAM", 0x1535, 1, prevRAM.ammo.powerCapacity)
		prevRAM.ammo.powerCount = prevRAM.ammo.powerCount + 5
		writeRAM("IWRAM", 0x153B, 1, prevRAM.ammo.powerCount)
	end

	-- Add tank to collected tanks in RAM
	local addr = 0x036C00 + newTank.areaID * 0x100
	while readRAM("EWRAM", addr, 1) ~= 0xFF do
		addr = addr + 4
	end
	
	writeRAM("EWRAM", addr + 0, 1, newTank.roomID)
	writeRAM("EWRAM", addr + 1, 1, newTank.tankType)
	writeRAM("EWRAM", addr + 2, 1, newTank.tankX)
	writeRAM("EWRAM", addr + 3, 1, newTank.tankY)

	writeRAM("IWRAM", 0x0063 + newTank.areaID, 1,
		readRAM("IWRAM", 0x0063 + newTank.areaID, 1) + 1)
	
	-- TODO: update minimap
	-- TODO: remove tank if in same room

	-- Return changes
	return prevRAM
end

-- Set an ability to be collected
function setAbilityCollected(prevAbility, newAbility)
	-- Set ability collected/equipped
	writeRAM("IWRAM", 0x153C, 4, 
		bit.bor(readRAM("IWRAM", 0x153C, 4), AbilityMap[newAbility.ability]))

	prevAbility[newAbility.ability] = true

	-- TODO: update VRAM for new beam
	-- if (abilityNum <= 2) then
	--
	-- do

	-- TODO: update minimap
	-- TODO: remove item if in same room

	return prevAbility
end

function removeTankFromRoom()
	-- TODO
end

function removeAbilityFromRoom()
	-- TODO
end

-- Set a game event state to new state
function setEvent(prevEvent, newEvent)
	-- for each even change...
	for event,active in pairs(newEvent) do
		local address = 0x037E00 + math.floor(event / 8)
		local eventflag = bit.lshift(0x01, event % 8)

		local eventbyte = readRAM("EWRAM", address, 1)
		if active then
			-- Set event to active
			eventbyte = bit.bor(eventbyte, eventflag)
		else
			-- Set event to inactive
			eventbyte = bit.band(eventbyte, bit.bnot(eventflag))
		end

		-- Update RAM
		prevEvent[event] = active
		writeRAM("EWRAM", address, 1, eventbyte)
	end

	return prevEvent
end

-- Set ammo counts to new updates
function setAmmo(prevAmmo, deltaAmmo)
	local newAmmo = {}

	if deltaAmmo.delta then
		-- If incremental delta changes, add values to current values
		-- deltas may be negative to subtract
		-- bound the updated values with the capacity and 0
		newAmmo.energyCount = math.max(math.min(prevAmmo.energyCount + 
			(deltaAmmo.energyCount or 0), prevAmmo.energyCapacity), 0)
		newAmmo.missileCount = math.max(math.min(prevAmmo.missileCount + 
			(deltaAmmo.missileCount or 0), prevAmmo.missileCapacity), 0)
		newAmmo.superCount = math.max(math.min(prevAmmo.superCount + 
			(deltaAmmo.superCount or 0), prevAmmo.superCapacity), 0)
		newAmmo.powerCount = math.max(math.min(prevAmmo.powerCount + 
			(deltaAmmo.powerCount or 0), prevAmmo.powerCapacity), 0)
	else
		-- If override changes, set the new value discarding the old value
		for ammo,value in pairs(prevAmmo) do
			newAmmo[ammo] = deltaAmmo[ammo] or value
		end

		-- Capcities are not updated from delta changes
		writeRAM("IWRAM", 0x1530, 2, newAmmo.energyCapacity)
		writeRAM("IWRAM", 0x1532, 2, newAmmo.missileCapacity)
		writeRAM("IWRAM", 0x1534, 1, newAmmo.superCapacity)
		writeRAM("IWRAM", 0x1535, 1, newAmmo.powerCapacity)
	end

	-- Update the counts in RAM
	writeRAM("IWRAM", 0x1536, 2, newAmmo.energyCount)
	writeRAM("IWRAM", 0x1538, 2, newAmmo.missileCount)
	writeRAM("IWRAM", 0x153A, 1, newAmmo.superCount)
	writeRAM("IWRAM", 0x153B, 1, newAmmo.powerCount)

	return newAmmo
end

-- Object that exposes the public functions
local mzm_ram = {}

-- RAM state from previous frame
local prevRAM = {
	ammo = {
		energyCount = 0,
		energyCapacity = 0,
		missileCount = 0,
		missileCapacity = 0,
		superCount = 0,
		superCapacity = 0,
		powerCount = 0,
		powerCapacity = 0
	},

	tanks = {},
	ability = {},
	events = {}
}

-- Gets a message to send to the other player of new changes
-- Returns the message as a dictionary object
-- Returns false if no message is to be send
function mzm_ram.getMessage()
	-- Gets the current RAM state
	local newRAM = {
		tanks = prevRAM.tanks,
		ability = getAbility(),
		events = getEvents(),
		ammo = getAmmo()
	}

	local message = {}
	local changed = false
	local newTank

	-- Gets the message for a new collected tank
	-- Also updates the states to squelch some changes
	newTank, prevRAM, newRAM = eventTankCollected(prevRAM, newRAM)
	if newTank then
		-- Add new changes
		message["t"] = newTank
		changed = true
	end

	-- Gets the message for a new collected ability
	local newAbility = eventAbilityCollected(prevRAM, newRAM)
	if newAbility then
		-- Add new changes
		message["a"] = newAbility
		changed = true
	end

	-- Gets the message for all changed game events
	local newEvent = eventTriggerEvent(prevRAM, newRAM)
	if newEvent then
		-- Add new changes
		message["e"] = newEvent
		changed = true
	end

	-- Gets the message for all updated ammo count/capacity
	local newAmmo = eventAmmoChange(prevRAM, newRAM)
	if newAmmo then
		-- Add new changes
		message["m"] = newAmmo
		changed = true
	end

	-- Update the frame pointer
	prevRAM = newRAM

	if changed then
		-- Send message
		return message
	else 
		-- No updates, no message
		return false
	end
end

-- Process a message from another player and update RAM
function mzm_ram.processMessage(message)
	-- Process new tank collected
	-- Does nothing if tank was already collected
	if message["t"] then
		prevRAM = setTankCollected(prevRAM, message["t"])
	end

	-- Process new ability collected
	if message["a"] then
		prevRAM.ability = setAbilityCollected(prevRAM.ability, message["a"])
	end

	-- process all changed game events
	if message["e"] then
		prevRAM.events = setEvent(prevRAM.events, message["e"])
	end

	-- process all ammo updates
	if message["m"] then
		prevRAM.ammo = setAmmo(prevRAM.ammo, message["m"])
	end
end

return mzm_ram