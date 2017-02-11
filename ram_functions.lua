-- initialize comparison values
prevEvents = { 0, 0, 0 }

prevEnergyCount = 99
prevEnergyCapacity = 99
prevMissileCount = 0
prevMissileCapacity = 0
prevSuperCount = 0
prevSuperCapacity = 0
prevPowerCount = 0
prevPowerCapacity = 0

prevCollectingTankFlag = 0

prevBeamBomb = 0
prevSuitMisc = 0


function setRAM(address, size, value)
	if size == 1 then
		memory.writebyte(address, value)
	elseif size == 2 then
		memory.writeword(address, value)
	elseif size == 4 then
		memory.writelong(address, value)
	end
end

function setTankCollected(tankType, areaID, roomID, tankX, tankY)
	-- add to list of collected items
	local addr = 0x2036C00 + areaID * 0x100
	while rom.readbyte(addr) ~= 0xFF do
		addr = addr + 4
	end
	
	memory.writebyte(addr, roomID)
	memory.writebyte(addr + 1, tankType)
	memory.writebyte(addr + 2, tankX)
	memory.writebyte(addr + 3, tankY)
	
	local numItemsCollected = memory.readbyte(0x3000063 + areaID)
	memory.writebyte(0x3000063 + areaID, numItemsCollected + 1)
	
	-- TODO: update minimap
	-- TODO: remove tank if in same room
end

-- this function will activate the item as soon as the other player collects it
-- otherwise, varia would be activated/deactivated three times
function setAbilityCollected(abilityNum, areaID, roomID, minimapX, minimapY)
	-- long beam
	if abilityNum == 0 then
		memory.writebyte(0x300153C, bit.bor(memory.readbyte(0x300153C), 1))
		memory.writebyte(0x300153D, bit.bor(memory.readbyte(0x300153D), 1))
		-- TODO: update VRAM
	-- ice beam
	elseif abilityNum == 1 then
		memory.writebyte(0x300153C, bit.bor(memory.readbyte(0x300153C), 2))
		memory.writebyte(0x300153D, bit.bor(memory.readbyte(0x300153D), 2))
		-- TODO: update VRAM
	-- wave beam
	elseif abilityNum == 2 then
		memory.writebyte(0x300153C, bit.bor(memory.readbyte(0x300153C), 4))
		memory.writebyte(0x300153D, bit.bor(memory.readbyte(0x300153D), 4))
		-- TODO: update VRAM
	-- plasma beam
	elseif abilityNum == 3 then
		memory.writebyte(0x300153C, bit.bor(memory.readbyte(0x300153C), 8))
	-- charge beam
	elseif abilityNum == 4 then
		memory.writebyte(0x300153C, bit.bor(memory.readbyte(0x300153C), 0x10))
		memory.writebyte(0x300153D, bit.bor(memory.readbyte(0x300153D), 0x10))
	-- bombs
	elseif abilityNum == 5 then
		memory.writebyte(0x300153C, bit.bor(memory.readbyte(0x300153C), 0x80))
		memory.writebyte(0x300153D, bit.bor(memory.readbyte(0x300153D), 0x80))
	-- hi-jump
	elseif abilityNum == 6 then
		memory.writebyte(0x300153E, bit.bor(memory.readbyte(0x300153E), 1))
		memory.writebyte(0x300153F, bit.bor(memory.readbyte(0x300153F), 1))
	-- speed booster
	elseif abilityNum == 7 then
		memory.writebyte(0x300153E, bit.bor(memory.readbyte(0x300153E), 2))
		memory.writebyte(0x300153F, bit.bor(memory.readbyte(0x300153F), 2))
	-- space jump
	elseif abilityNum == 8 then
		memory.writebyte(0x300153E, bit.bor(memory.readbyte(0x300153E), 4))
	-- screw attack
	elseif abilityNum == 9 then
		memory.writebyte(0x300153E, bit.bor(memory.readbyte(0x300153E), 8))
		memory.writebyte(0x300153F, bit.bor(memory.readbyte(0x300153F), 8))
	-- varia suit
	elseif abilityNum == 10 then
		memory.writebyte(0x300153E, bit.bor(memory.readbyte(0x300153E), 0x10))
		memory.writebyte(0x300153F, bit.bor(memory.readbyte(0x300153F), 0x10))
	-- gravity suit
	elseif abilityNum == 11 then
		memory.writebyte(0x300153E, bit.bor(memory.readbyte(0x300153E), 0x20))
	-- morph ball
	elseif abilityNum == 12 then
		memory.writebyte(0x300153E, bit.bor(memory.readbyte(0x300153E), 0x40))
		memory.writebyte(0x300153F, bit.bor(memory.readbyte(0x300153F), 0x40))
	-- power grip
	elseif abilityNum == 13 then
		memory.writebyte(0x300153E, bit.bor(memory.readbyte(0x300153E), 0x80))
		memory.writebyte(0x300153F, bit.bor(memory.readbyte(0x300153F), 0x80))
	end
	
	prevBeamBomb = memory.readbyte(0x300153C)
	prevSuitMisc = memory.readbyte(0x300153E)
	
	-- TODO: update minimap
	-- TODO: remove item if in same room
end

function removeTankFromRoom()
	-- TODO
end

function removeAbilityFromRoom()
	-- TODO
end

function checkEventChanged()
	for i=0,2 do
		local event = memory.readlong(0x2037E00 + i*4)
		if prevEvents[i+1] ~= event then
			prevEvents[i+1] = event
			-- TODO: call setRAM(0x2037E00 + i*4, 4, event)
		end
	end
end

function checkAmmoChanged()
	-- energy count
	local energyCount = memory.readword(0x3001536)
	if prevEnergyCount ~= energyCount then
		prevEnergyCount = energyCount
		-- TODO: call setRAM(0x3001536, 2, energyCount)
	end
	-- energy capacity
	local energyCapacity = memory.readword(0x3001530)
	if prevEnergyCapacity ~= energyCapacity then
		prevEnergyCapacity = energyCapacity
		-- TODO: call setRAM(0x3001530, 2, energyCapacity)
	end
	-- missile count
	local missileCount = memory.readword(0x3001538)
	if prevMissileCount ~= missileCount then
		prevMissileCount = missileCount
		-- TODO: call setRAM(0x3001538, 2, missileCount)
	end
	-- missile capacity
	local missileCapacity = memory.readword(0x3001532)
	if prevMissileCapacity ~= missileCapacity then
		prevMissileCapacity = missileCapacity
		-- TODO: call setRAM(0x3001532, 2, missileCapacity)
	end
	-- super count
	local superCount = memory.readword(0x300153A)
	if prevSuperCount ~= superCount then
		prevSuperCount = superCount
		-- TODO: call setRAM(0x300153A, 1, superCount)
	end
	-- super capacity
	local superCapacity = memory.readword(0x3001534)
	if prevSuperCapacity ~= superCapacity then
		prevSuperCapacity = superCapacity
		-- TODO: call setRAM(0x3001534, 1, superCapacity)
	end
	-- power count
	local powerCount = memory.readword(0x300153B)
	if prevPowerCount ~= powerCount then
		prevPowerCount = powerCount
		-- TODO: call setRAM(0x300153B, 1, powerCount)
	end
	-- power capacity
	local powerCapacity = memory.readword(0x3001535)
	if prevPowerCapacity ~= powerCapacity then
		prevPowerCapacity = powerCapacity
		-- TODO: call setRAM(0x3001535, 1, powerCapacity)
	end
end

function checkTankCollected()
	local collectingTankFlag = memory.readbyte(0x3000044)
	if prevCollectingTankFlag ~= collectingTankFlag then
		prevCollectingTankFlag = collectingTankFlag
		if collectingTankFlag == 1 then
			local tankType = memory.readbyte(0x30056A8) - 0x38
			local areaID = memory.readbyte(0x3000054)
			local roomID = memory.readbyte(0x3000055)
			local tankX = memory.readbyte(0x30056AA)
			local tankY = memory.readbyte(0x30056AB)
			-- TODO: call setTankCollected(tankType, areaID, roomID, tankX, tankY)
		end
	end
end

function checkAbilityCollected()
	local abilityNum = -1
	
	-- check beam/bombs
	local beamBomb = memory.readbyte(0x300153C)
	if prevBeamBomb ~= beamBomb then
		local flag = bit.bxor(prevBeamBomb, beamBomb)
		abilityNum = getAbilityNum(flag, true)
		prevBeamBomb = beamBomb
	end
	
	-- check suit/misc
	local suitMisc = memory.readbyte(0x300153E)
	if prevSuitMisc ~= suitMisc then
		local flag = bit.bxor(prevSuitMisc, suitMisc)
		abilityNum = getAbilityNum(flag, false)
		prevSuitMisc = suitMisc
	end
	
	if flag ~= -1 then
		local areaID = memory.readbyte(0x3000054)
		local roomID = memory.readbyte(0x3000055)
		local minimapX = memory.readbyte(0x3000059)
		local minimapY = memory.readbyte(0x300005A)
		-- TODO: call setAbilityCollected(abilityNum, areaID, roomID, minimapX, minimapY)
	end
end

function getAbilityNum(flag, isBeamBomb)
	if isBeamBomb and flag == 0x80 then
		return 5
	end
	
	local number = 0
	while flag ~= 1 do
		flag = bit.rshift(flag, 1)
		number = number + 1
	end
	
	if not isBeamBomb then
		number = number + 6
	end
	
	return number
end

-- example of main loop
while true do

	-- TODO: check for input from other player
	-- based on input from other player, call appropriate functions
		-- call setRAM if ammo or event has changed
		-- call setTankCollected if a tank was collected
		-- call setAbilityCollected if an ability was collected
	
	-- check to send output to other player
	checkEventChanged()
	checkAmmoChanged()
	checkTankCollected()
	checkAbilityCollected()
	
	-- advance one frame
	vba.frameadvance()

end
