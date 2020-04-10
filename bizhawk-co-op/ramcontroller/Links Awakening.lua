local NO_ITEM_VALUE = 0x00

local MAX_NUM_HEART_CONTAINERS = 0x0E -- 14
local MAX_NUM_HEART_PIECES = 0x04
local MAX_SWORD_LEVEL = 0x02
local MAX_SHIELD_LEVEL = 0x02
local MAX_BRACELET_LEVEL = 0x02
local MAX_TRADING_ITEM = 0x0E
local MAX_GOLDEN_LEAVES = 0x06

local LOG_LEVEL_VERBOSE = 'Verbose'

-- Source: https://datacrystal.romhacking.net/wiki/The_Legend_of_Zelda:_Link%27s_Awakening:RAM_map
local inventoryItemVals = {
    [NO_ITEM_VALUE] = 'Nothing',
    [0x01] = 'Sword',
    [0x02] = 'Bombs',
    [0x03] = 'Power bracelet',
    [0x04] = 'Shield',
    [0x05] = 'Bow',
    [0x06] = 'Hookshot',
    [0x07] = 'Fire rod',
    [0x08] = 'Pegasus boots',
    [0x09] = 'Ocarina',
    [0x0A] = 'Feather',
    [0x0B] = 'Shovel',
    [0x0C] = 'Magic powder',
    [0x0D] = 'Boomrang',
}

local B_SLOT_ADDR = 0xDB00

local NEW_INV_ITEMS_KEY = 'New inventory Items List'

local inventorySlotInfos = { --Order is important, since we want to add items to the first available slot
    {address = B_SLOT_ADDR, name = 'B Slot'},
    {address = 0xDB01, name = 'A Slot'},
    {address = 0xDB02, name = 'Inv 01'},
    {address = 0xDB03, name = 'Inv 02'},
    {address = 0xDB04, name = 'Inv 03'},
    {address = 0xDB05, name = 'Inv 04'},
    {address = 0xDB06, name = 'Inv 05'},
    {address = 0xDB07, name = 'Inv 06'},
    {address = 0xDB08, name = 'Inv 07'},
    {address = 0xDB09, name = 'Inv 08'},
    {address = 0xDB0A, name = 'Inv 09'},
    {address = 0xDB0B, name = 'Inv 10'},
}

local MAP_FLAGS_BASE_ADDR = 0xD800

local gameStateAddr = 0xDB95
-- Source https://github.com/zladx/LADX-Disassembly/blob/4ae748bd354f94ed2887f04d4014350d5a103763/src/constants/gameplay.asm#L22-L48
local gameStateVals = { -- Only states where we can do events are listed
    [0x07] = 'Map Screen',
    [0x0B] = 'Main Gameplay',
    [0x0C] = 'Inventory Screen',
}

local menuStateAddr = 0xDB9A
local menuStateVals = {
    [0x00] = {desc = 'Pause Menu', transmitEvents = true},
    [0x80] = {desc = 'Game running/Title Screen Running', transmitEvents = true},
    [0xFF] = {desc = 'Death/Save+Quit Menu', transmitEvents = false}, 
}

-- There are 16 non-player entities that can be tracked on screen at once
local ENTITY_TABLE_LENGTH = 0x10

local ENTITY_STATUS_TABLE_START_ADDR = 0xC280
local ENTITY_STATUS_ACTIVE_VAL = 0x05

-- Entity state. Each entity has its own meaning for each value
local ENTITY_STATE_1_TABLE_START_ADDR = 0xC290
local ENTITY_STATE_1_BIG_FAIRY_INTERACTING_VAL = 0x01

local ENTITY_STATE_2_TABLE_STRT_ADDR = 0xC2B0
local ENTITY_STATE_2_BIG_FAIRY_HEAL_START_COUNTER_VAL = 0x04

local ENTITY_TYPE_TABLE_START_ADDR = 0xC3A0
local ENTITY_TYPE_BIG_FAIRY_VAL = 0x84

local BIG_FAIRY_HEALING_KEY = 'Healing from big fairy'

local ADD_HEALTH_BUFFER_ADDR = 0xDB93
local BIG_FAIRY_HEALING_BUFFER_VAL = 0x04

function tableCount(table)
    local count = 0
    for _, _ in pairs(table) do
        count = count + 1
    end
    return count
end

function tableString(table)

    local returnStr = '{'
    for key,value in pairs(table) do
        returnStr = returnStr..string.format('%s=%s,', asString(key), asString(value))
    end
    returnStr = returnStr..'}'
    return returnStr
end


function asString(object)

    if type(object) == 'table' then
        return tableString(object)
    elseif type(object) == 'number' then
        return string.format('%x', object)
    else
        return tostring(object)
    end
end

local prevRAM = nil

local gameLoaded = false
local prevGameLoaded = false
local prevBigFairyHealing = false

-- keys: string of player name, value: true/false if they were previously fairy healing
local prevRemotePlayerBigFairyHealing = {}
local ramController = {}

-- Writes value to RAM using little endian
function writeRAM(address, size, value)

    -- default size byte
    if (size == nil) then
        size = 1
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
    else
        console.log(string.format('ERROR: Attempt to write illegal length memory block [%s] from address [%s]. Legal lengths are 1, 2, 4.', size, address))
    end
end

-- Reads a value from RAM using little endian
function readRAM(address, size)

    -- default size byte
    if (size == nil) then
        size = 1
    end

    if size == 1 then
        return memory.readbyte(address)
    elseif size == 2 then
        return memory.read_u16_le(address)
    elseif size == 4 then
        return memory.read_u32_le(address)
    else
        console.log(string.format('ERROR: Attempt to read illegal length memory block [%s] from address [%s]. Legal lengths are 1, 2, 4.', size, address))
    end
end

function isGameLoaded(gameStateVal)
    return gameStateVals[gameStateVal] ~= nil
end

function isGameLoadedWithFetch() -- Grr. Why doesn't lua support function overloading??
    return isGameLoaded(readRAM(gameStateAddr))
end

function healthToString(val)

    local whole = math.floor(val / 8)
    val = val - (whole * 8)

    local part = nil
    if val > 0 then
        if val % 4 == 0 then
            part = (val / 4) .. '/2'
        elseif val % 2 == 0 then
            part = (val / 2) .. '/4'
        else
            part = val .. '/8'
        end
    end

    if whole > 0 and part then
        return whole .. ' ' .. part
    elseif whole > 0 then
        return whole
    else
        return part
    end
end

function reverseU16Int(value)
    return ((value % 256) * 256) + math.floor(value / 256)
end

local ramItemAddrs = {
    [0xCFF2] = {name = 'Overworld Sword', type = 'num'},
    [0xDB0C] = {name = 'Flippers', type = 'bool'},
    [0xDB0D] = {name = 'Potion', type = 'bool'},
    [0xDB0E] = {name = 'Trading Item', type = 'num', maxVal = MAX_TRADING_ITEM},
    [0xDB0F] = {name = 'Number of secret shells', type = 'num'},
    [0xDB11] = {name = 'Tail Key', type = 'bool'},
    [0xDB12] = {name = 'Angler Key', type = 'bool'},
    [0xDB13] = {name = 'Face Key', type = 'bool'},
    [0xDB14] = {name = 'Birdie Key', type = 'bool'},
    [0xDB15] = {name = 'Number of golden leaves', type = 'num', maxVal = MAX_GOLDEN_LEAVES},
    [0xDB16] = {name = 'Tail Cave Map', type = 'bool'},
    [0xDB17] = {name = 'Tail Cave Compass', type = 'bool'},
    [0xDB18] = {name = 'Tail Cave Owl\'s Beak', type = 'bool'},
    [0xDB19] = {name = 'Tail Cave Nightmare Key', type = 'bool'},
    [0xDB1A] = {name = 'Tail Cave Small Keys', type = 'num'},
    [0xDB1B] = {name = 'Bottle Grotto Map', type = 'bool'},
    [0xDB1C] = {name = 'Bottle Grotto Compass', type = 'bool'},
    [0xDB1D] = {name = 'Bottle Grotto Owl\'s Beak', type = 'bool'},
    [0xDB1E] = {name = 'Bottle Grotto Nightmare Key', type = 'bool'},
    [0xDB1F] = {name = 'Bottle Grotto Small Keys', type = 'num'},
    [0xDB20] = {name = 'Key Cavern Map', type = 'bool'},
    [0xDB21] = {name = 'Key Cavern Compass', type = 'bool'},
    [0xDB22] = {name = 'Key Cavern Owl\'s Beak', type = 'bool'},
    [0xDB23] = {name = 'Key Cavern Nightmare Key', type = 'bool'},
    [0xDB24] = {name = 'Key Cavern Small Keys', type = 'num'},
    [0xDB25] = {name = 'Angler\'s Tunnel Map', type = 'bool'},
    [0xDB26] = {name = 'Angler\'s Tunnel Compass', type = 'bool'},
    [0xDB27] = {name = 'Angler\'s Tunnel Owl\'s Beak', type = 'bool'},
    [0xDB28] = {name = 'Angler\'s Tunnel Nightmare Key', type = 'bool'},
    [0xDB29] = {name = 'Angler\'s Tunnel Small Keys', type = 'num'},
    [0xDB2A] = {name = 'Catfish\'s Maw Map', type = 'bool'},
    [0xDB2B] = {name = 'Catfish\'s Maw Compass', type = 'bool'},
    [0xDB2C] = {name = 'Catfish\'s Maw Owl\'s Beak', type = 'bool'},
    [0xDB2D] = {name = 'Catfish\'s Maw Nightmare Key', type = 'bool'},
    [0xDB2E] = {name = 'Catfish\'s Maw Small Keys', type = 'num'},
    [0xDB2F] = {name = 'Face Shrine Map', type = 'bool'},
    [0xDB30] = {name = 'Face Shrine Compass', type = 'bool'},
    [0xDB31] = {name = 'Face Shrine Owl\'s Beak', type = 'bool'},
    [0xDB32] = {name = 'Face Shrine Nightmare Key', type = 'bool'},
    [0xDB33] = {name = 'Face Shrine Small Keys', type = 'num'},
    [0xDB34] = {name = 'Eagle\'s Tower Map', type = 'bool'},
    [0xDB35] = {name = 'Eagle\'s Tower Compass', type = 'bool'},
    [0xDB36] = {name = 'Eagle\'s Tower Owl\'s Beak', type = 'bool'},
    [0xDB37] = {name = 'Eagle\'s Tower Nightmare Key', type = 'bool'},
    [0xDB38] = {name = 'Eagle\'s Tower Small Keys', type = 'num'},
    [0xDB39] = {name = 'Turtle Rock Map', type = 'bool'},
    [0xDB3A] = {name = 'Turtle Rock Compass', type = 'bool'},
    [0xDB3B] = {name = 'Turtle Rock Owl\'s Beak', type = 'bool'},
    [0xDB3C] = {name = 'Turtle Rock Nightmare Key', type = 'bool'},
    [0xDB3D] = {name = 'Turtle Rock Small Keys', type = 'num'},
    [0xDB43] = {name = 'Power bracelet level', type = 'num', maxVal = MAX_BRACELET_LEVEL},
    [0xDB44] = {name = 'Shield level', type = 'num', maxVal = MAX_SHIELD_LEVEL},
    [0xDB45] = {name = 'Number of arrows', type = 'num', flag = 'ammo'},
    [0xDB49] = {name = {
        [0] = 'Frog\'s Song of Soul',
        [1] = 'Manbo Mambo',
        [2] = 'Ballad of the Wind Fish'
    }, type = 'bitmask'},
    -- [0xDB4A] = {name = 'Ocarina selected song', type = 'num'}, Add only for inventory insanity
    [0xDB4B] = {name = 'Toadstool', type = 'bool'},
    [0xDB4C] = {name = 'Magic powder quantity', type = 'num', flag = 'ammo'},
    [0xDB4D] = {name = 'Number of bombs', type = 'num', flag = 'ammo'},
    [0xDB4E] = {name = 'Sword level', type = 'num', maxVal = MAX_SWORD_LEVEL},
--    DB56-DB58 Number of times the character died for each save slot (one byte per save slot)
    --[0xDB5A] = {name = 'Current health', type = 'num', flag = 'life'}, --Each increment of 08 is one full heart, each increment of 04 is one-half heart (Don't set this directly. Use the health buffers)
    [0xDB5B] = {name = 'Maximum health', type = 'num', maxVal = MAX_NUM_HEART_CONTAINERS}, --Max recommended value is 0E (14 hearts)
    [0xDB5C] = {name = 'Number of heart pieces', type = 'num', maxVal = MAX_NUM_HEART_PIECES},
    --[0xDB5D] = {name = 'Rupees', type = 'num', flag = 'money', size = 2}, --2 bytes, decimal value (Don't set this directly. Use the buffers)
--    [0xDBAE] = {name = 'Dungeon map grid position', type = 'num'},
    [0xDB65] = {name = 'Tail Cave', type = 'num', instrumentName = 'Full Moon Cello'}, -- 00=starting state, 01=defeated miniboss, 02=???, 03=have instrument
    [0xDB66] = {name = 'Bottle Grotto', type = 'num', instrumentName = 'Conch Horn'},
    [0xDB67] = {name = 'Key Cavern', type = 'num', instrumentName = 'Sea Lily\'s Bell'},
    [0xDB68] = {name = 'Angler\'s Tunnel', type = 'num', instrumentName = 'Surf Harp'},
    [0xDB69] = {name = 'Catfish\'s Maw', type = 'num', instrumentName = 'Wind Marimba'},
    [0xDB6A] = {name = 'Face Shrine', type = 'num', instrumentName = 'Coral Triangle'},
    [0xDB6B] = {name = 'Eagle\'s Tower', type = 'num', instrumentName = 'Organ of Evening Calm'},
    [0xDB6C] = {name = 'Turtle Rock', type = 'num', instrumentName = 'Thunder Drum'},
    [0xDB76] = {name = 'Max magic powder', type = 'num'},
    [0xDB77] = {name = 'Max bombs', type = 'num'},
    [0xDB78] = {name = 'Max arrows', type = 'num'},
    -- Buffers are rupee/health amounts that are to be added to your total over time.
    -- Picking up rupees/health adds to the "add" buffers. Paying money/taking damage adds to the "subtract" buffers.
    -- The game subtracts from these buffers over time, applying their effect to your money/health totals
    -- Only additions to buffer values should be transmitted
    [0xDB8F] = {name = 'Rupees Added', type = 'buffer', flag = 'rupees', size = 2, displayFunc = function(user, val) return string.format("%s found %s rupees", user, val) end },
    [0xDB91] = {name = 'Rupees Spent', type = 'buffer', flag = 'rupees', size = 2, displayFunc = function(user, val) return string.format("%s spent %s rupees", user, val) end },
    [ADD_HEALTH_BUFFER_ADDR] = {name = 'Health Added', type = 'buffer', flag = 'health', displayFunc = function(user, val) return string.format("%s got %s hearts of health", user, healthToString(val)) end },
    [0xDB94] = {name = 'Health Lost', type = 'buffer', flag = 'health', displayFunc = function(user, val) return string.format("%s lost %s hearts of health", user, healthToString(val)) end },
    [0xDC0F] = {name = 'Tunic Color', type = 'num'},
    [0xDDDA] = {name = 'Color Dungeon Map', type = 'bool'},
    [0xDDDB] = {name = 'Color Dungeon Compass', type = 'bool'},
    [0xDDDC] = {name = 'Color Dungeon Owl\'s Beak', type = 'bool'},
    [0xDDDD] = {name = 'Color Dungeon Nightmare Key', type = 'bool'},
    [0xDDDE] = {name = 'Color Dungeon Small Keys', type = 'num'},
}

for _, slotInfo in pairs(inventorySlotInfos) do
    ramItemAddrs[slotInfo['address']] = {name = slotInfo['name'], type = 'Inventory Slot'}
end

-- Add each map tile's explored flag to the sync locations
for mapTileIndex=0,256 do
    ramItemAddrs[MAP_FLAGS_BASE_ADDR + mapTileIndex] = {name = {
        [7] = 'Map tile explored'
    }, type = 'bitmask', silent = true}
end


-- Display a message of the ram event
function getGUImessage(address, prevVal, newVal, user)
    -- Only display the message if there is a name for the address
    local name = ramItemAddrs[address].name
    local silent = ramItemAddrs[address].silent
    if name and not silent and prevVal ~= newVal then

        local itemType = ramItemAddrs[address].type

        -- If boolean, show 'Removed' for false
        if itemType == 'bool' then
            gui.addmessage(string.format('%s: %s %s', user, (newVal == 0 and 'Removed' or 'Added'), name))

        -- If numeric, show the name with value
        elseif itemType == 'num' then

            local instrumentName = ramItemAddrs[address].instrumentName
            if instrumentName then
                if newVal == 0 then
                    gui.addmessage(string.format('%s: Reset %s', user, name))
                elseif newVal == 1 then
                    gui.addmessage(string.format('%s: Defeated mini-boss in %s', user, name))
                elseif newVal == 3 then
                    gui.addmessage(string.format('%s: Got instrument %s', user, instrumentName))
                end
            else
                gui.addmessage(string.format('%s: %s = %s', user, name, newVal))
            end

        -- If bitflag, show each bit: the indexed name or bit index as a boolean
        elseif itemType == 'bitmask' then
            for b=0,7 do
                if ramItemAddrs[address].name[b] then
                    local newBit = bit.check(newVal, b)
                    local prevBit = bit.check(prevVal, b)

                    if (newBit ~= prevBit) then
                        gui.addmessage(string.format('%s: %s %s', user, (newBit and 'Added' or ' Removed'), name[b]))
                    end
                end
            end

        -- If an inventory item, just show the inventory item name
        elseif itemType == 'Inventory Slot' then
            gui.addmessage(string.format('%s: Found %s', user, inventoryItemVals[newVal]))
        elseif itemType == 'buffer' then
            if newVal > prevVal then
                gui.addmessage(ramItemAddrs[address].displayFunc(user, newVal - prevVal))
            end
        else
            gui.addmessage(string.format('Unknown item ram type %s', itemType))
        end
    end
end

function giveInventoryItem(itemVal, prevRAM, their_user)

    local firstEmptySlotAddr = nil

    for _, slotInfo in ipairs(inventorySlotInfos) do
        local slotAddr = slotInfo['address']
        local thisSlotsItem = readRAM(slotAddr, 1)
        if thisSlotsItem == itemVal then
            return -- We already have this item. Just ignore this request.
        end
        if thisSlotsItem == NO_ITEM_VALUE and not firstEmptySlotAddr then
            firstEmptySlotAddr = slotAddr
        end
    end

    if not firstEmptySlotAddr then
        console.log(string.format('ERROR: Attempt to award item %s, but all inventory slots are full!', inventoryItemVals[itemVal]))
        return
    end


    if config.ramconfig.verbose then
        printOutput(string.format('About to write item val %s (%s) to addr %s', asString(itemVal), asString(inventoryItemVals[itemVal]), asString(firstEmptySlotAddr)))
    end

    writeRAM(firstEmptySlotAddr, 1, itemVal)

    getGUImessage(firstEmptySlotAddr, prevRAM[address], itemVal, their_user)

    -- Write the itemVal to the previous memory state so that the update check doesn't think we found this item
    prevRAM[firstEmptySlotAddr] = itemVal
end

function removeInventoryItem(itemVal, prevRAM, their_user)

    for _, slotInfo in ipairs(inventorySlotInfos) do
        local slotAddr = slotInfo['address']
        local thisSlotsItem = readRAM(slotAddr, 1)
        if thisSlotsItem == itemVal then
            writeRAM(slotAddr, 1, NO_ITEM_VALUE)
            return
        end
    end
end

-- Reset this script's record of your possessed items to what's currently in memory, ignoring any previous state
-- Used when entering into a playable state, such as when loading a save
function getPossessedItemsTable(itemsState)

    -- Create a blank possessed items table
    local itemsTable = {}
    for memVal, itemName in pairs(inventoryItemVals) do
        if memVal ~= NO_ITEM_VALUE then
            itemsTable[memVal] = false
        end
    end

    -- Search the passed-in itemsState for items and mark all found items as possessed
    for _, slotInfo in pairs(inventorySlotInfos) do
        local slotAddr = slotInfo['address']
        local itemInSlot = itemsState[slotAddr]
        if not itemInSlot then
            error(string.format('Unable to find item in slot %s. Items state: %s', asString(slotAddr), asString(itemsState)))
        end
        if itemInSlot ~= NO_ITEM_VALUE then
            itemsTable[itemInSlot] = true
        end
    end

    return itemsTable
end


-- Get the list of ram values
function getTransmittableItemsState()

    local transmittableTable = {}
    for address, item in pairs(ramItemAddrs) do
        local skip = false
        if not config.ramconfig.ammo and item.flag == 'ammo' then
            skip = true
        end

        if not config.ramconfig.health and item.flag == 'health' then
            skip = true
        end

        if not config.ramconfig.rupees and item.flag == 'rupees' then
            skip = true
        end

        if not skip then
            -- Default byte length to 1
            if (not item.size) then
                item.size = 1
            end

            local ramval = readRAM(address, item.size)
            if item.flag == 'rupees' then
                ramval = reverseU16Int(ramval)
            end

            transmittableTable[address] = ramval
        end
    end

    return transmittableTable
end

function isBigFairyHealing()

    for index = 0,(ENTITY_TABLE_LENGTH - 1) do

        local entityType = readRAM(ENTITY_TYPE_TABLE_START_ADDR + index, 1)
        if entityType == ENTITY_TYPE_BIG_FAIRY_VAL then

            local bigFairyStatus = readRAM(ENTITY_STATUS_TABLE_START_ADDR + index, 1)
            local bigFairyInteractingState = readRAM(ENTITY_STATE_1_TABLE_START_ADDR + index, 1)
            local bigFairyHealCounter = readRAM(ENTITY_STATE_2_TABLE_STRT_ADDR + index, 1)

            if bigFairyStatus == ENTITY_STATUS_ACTIVE_VAL and
                bigFairyInteractingState == ENTITY_STATE_1_BIG_FAIRY_INTERACTING_VAL and
                bigFairyHealCounter >= ENTITY_STATE_2_BIG_FAIRY_HEAL_START_COUNTER_VAL then

                return true
            end
        end
    end

    return false
end


-- Get a list of changed ram events
function getItemStateChanges(prevState, newState)
    local ramevents = {}
    local changes = false

    -- Big fairy healing needs a special event type.
    -- For health buffers, we rely on increases to the buffer. The big fairy sets it to 4 and holds it there over time,
    -- meaning only 4 (1/2 heart) gets transmitted, but the buffer drains/resets before we can check for events,
    -- so it only gets set once.
    if isBigFairyHealing() then
        ramevents[BIG_FAIRY_HEALING_KEY] = true
        if not prevBigFairyHealing then
            gui.addmessage(string.format('%s: Started healing at a Great Fairy', config.user))
        end
        prevBigFairyHealing = true
        changes = true
        -- Suppress the normal add buffer event for big fairy healing
        prevState[ADD_HEALTH_BUFFER_ADDR] = BIG_FAIRY_HEALING_BUFFER_VAL
    else
        prevBigFairyHealing = false
    end

    for address, val in pairs(newState) do

        local prevVal = prevState[address]
        local itemType = ramItemAddrs[address].type

        -- If change found
        if (prevVal ~= val) then

            if config.ramconfig.verbose then
                printOutput(string.format('Updating address [%s] to value [%s].', asString(address), asString(val)))
            end

            -- If boolean, get T/F
            if itemType == 'bool' then
                getGUImessage(address, prevVal, val, config.user)
                ramevents[address] = (val ~= 0)
                changes = true

            -- If numeric, get value
            elseif itemType == 'num' then
                getGUImessage(address, prevVal, val, config.user)
                ramevents[address] = val
                changes = true

            -- If bitmask, get the changed bits
            elseif itemType == 'bitmask' then
                getGUImessage(address, prevVal, val, config.user)
                local changedBits = {}
                for b=0,7 do
                    if ramItemAddrs[address].name[b] then
                        local newBit = bit.check(val, b)
                        local prevBit = bit.check(prevVal, b)

                        if (newBit ~= prevBit) then
                            changedBits[b] = newBit
                        end
                    end
                end
                ramevents[address] = changedBits
                changes = true

            -- Only transmit buffer increases
            elseif itemType == 'buffer' then
                getGUImessage(address, prevVal, val, config.user)
                if val > prevVal then
                    ramevents[address] = val - prevVal
                    changes = true
                end

            elseif itemType == 'Inventory Slot' then
                -- Do nothing. We do a separate check for new inventory items below
            else 
                console.log(string.format('Unknown item type [%s] for item %s (Address: %s)', itemType, ramItemAddrs[address].name, address))
            end
        end
    end

    local prevPossessedItems = getPossessedItemsTable(prevState)
    local newPossessedItems = getPossessedItemsTable(newState)

    local invItemChanges = {}

    for itemVal, isPrevPossessed in pairs(prevPossessedItems) do
        local isNewPossessed = newPossessedItems[itemVal]
        if not isPrevPossessed and isNewPossessed then

            if config.ramconfig.verbose then
                printOutput(string.format('Discovered that item [%s] is newly possessed.', itemVal))
                printOutput(string.format('Previous possessed table: %s', asString(prevPossessedItems)))
                printOutput(string.format('New possessed table: %s', asString(newPossessedItems)))
            end
            changes = true
            invItemChanges[itemVal] = 'Added'
            getGUImessage(B_SLOT_ADDR, NO_ITEM_VALUE, itemVal, config.user)
        end
        if isPrevPossessed and not isNewPossessed then
            if config.ramconfig.verbose then
                printOutput(string.format('Discovered that item [%s] was possessed, but has been lost (boomerang trade).', itemVal))
                printOutput(string.format('Previous possessed table: %s', asString(prevPossessedItems)))
                printOutput(string.format('New possessed table: %s', asString(newPossessedItems)))
            end
            changes = true
            invItemChanges[itemVal] = 'Removed'
            getGUImessage(B_SLOT_ADDR, itemVal, NO_ITEM_VALUE, config.user)
        end
    end

    if tableCount(invItemChanges) > 0 then
        ramevents[NEW_INV_ITEMS_KEY] = invItemChanges
    end

    if (changes) then
        if config.ramconfig.verbose then
            printOutput(string.format('Found events to send: %s', asString(ramevents)))
        end
        return ramevents
    else
        return false
    end
end


-- set a list of ram events
function applyItemStateChanges(prevRAM, their_user, newEvents)

    -- First, handle the newly acquired inventory items
    local invItemChanges = newEvents[NEW_INV_ITEMS_KEY]
    local itemRemoves = {}
    local itemAdds = {}
    if invItemChanges then
        for itemVal, eventType in pairs(invItemChanges) do
            if config.ramconfig.verbose then
                printOutput(string.format('From %s: Item: %s was %s', their_user, asString(inventoryItemVals[itemVal]), eventType))
            end
            if eventType == 'Added' then
                table.insert(itemAdds, itemVal)
            
            elseif eventType == 'Removed' then
                table.insert(itemRemoves, itemVal)
            end
        end
    end
    newEvents[NEW_INV_ITEMS_KEY] = nil

    for _,itemVal in pairs(itemRemoves) do
        removeInventoryItem(itemVal, prevRAM, their_user)
    end

    for _,itemVal in pairs(itemAdds) do
        giveInventoryItem(itemVal, prevRAM, their_user)
    end

    if newEvents[BIG_FAIRY_HEALING_KEY] then
        prevRAM[ADD_HEALTH_BUFFER_ADDR] = BIG_FAIRY_HEALING_BUFFER_VAL
        writeRAM(ADD_HEALTH_BUFFER_ADDR, ramItemAddrs[ADD_HEALTH_BUFFER_ADDR].size, BIG_FAIRY_HEALING_BUFFER_VAL)
        if not prevRemotePlayerBigFairyHealing[their_user] then
            gui.addmessage(string.format('%s: Started healing at a Great Fairy', their_user))
        end
        prevRemotePlayerBigFairyHealing[their_user] = true
    else
        prevRemotePlayerBigFairyHealing[their_user] = false
    end
    newEvents[BIG_FAIRY_HEALING_KEY] = nil

    for address, val in pairs(newEvents) do

        local itemType = ramItemAddrs[address].type
        local newval

        if config.ramconfig.verbose then
            printOutput(string.format('Applying state change [%s=%s]', asString(address), asString(val)))
        end
        -- If boolean type value
        if itemType == 'bool' then
            newval = (val and 1 or 0) -- Coercing booleans back to 1 or 0 numeric

        -- If numeric type value
        elseif itemType == 'num' then
            local maxVal = ramItemAddrs[address].maxVal
            if maxVal and val > maxVal then
                newval = maxVal
            else
                newval = val
            end

        -- If bitflag update each bit
        elseif itemType == 'bitmask' then
            newval = prevRAM[address]
            for b, bitval in pairs(val) do
                if bitval then
                    newval = bit.set(newval, b)
                else
                    newval = bit.clear(newval, b)
                end
            end

        elseif itemType == 'buffer' then
            newval = prevRAM[address] + val

        else 
            printOutput(string.format('Unknown item type [%s] for item %s (Address: %s)', itemType, ramItemAddrs[address].name, address))
            newval = prevRAM[address]
        end

        -- Write the new value
        getGUImessage(address, prevRAM[address], newval, their_user)
        prevRAM[address] = newval
        local gameLoaded = isGameLoadedWithFetch()
        if gameLoaded then
            local valToWrite = newval
            if ramItemAddrs[address].flag == 'rupees' then

                if config.ramconfig.verbose then
                    printOutput(string.format('About to reverse rupees: %s', asString(valToWrite)))
                end
                valToWrite = reverseU16Int(valToWrite)
                if config.ramconfig.verbose then
                    printOutput(string.format('About to write rupees: %s', asString(valToWrite)))
                end
            end
            writeRAM(address, ramItemAddrs[address].size, valToWrite)
        end
    end    
    return prevRAM
end


client.reboot_core()
ramController.itemcount = tableCount(ramItemAddrs)

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
  if messageQueue.isEmpty() then error('list is empty') end
  local value = messageQueue[first]
  messageQueue[first] = nil        -- to allow garbage collection
  messageQueue.first = first + 1
  return value
end
function messageQueue.popRight ()
  local last = messageQueue.last
  if messageQueue.isEmpty() then error('list is empty') end
  local value = messageQueue[last]
  messageQueue[last] = nil         -- to allow garbage collection
  messageQueue.last = last - 1
  return value
end


-- Gets a message to send to the other player of new changes
-- Returns the message as a dictionary object
-- Returns false if no message is to be send
function ramController.getMessage()
    -- Check if game is playing
    local gameLoaded = isGameLoadedWithFetch()

    -- Don't check for updated when game is not running
    if not gameLoaded then
        return false
    end

    -- Don't bother transmitting events if we're in a menu state that would preclude that (e.g. Game Over screen)
    menuState = readRAM(menuStateAddr)
    local currentMenuState = menuStateVals[menuState]
    if not currentMenuState then
        error(string.format('Menu state contains unknown value [%s]', menuState))
        return false
    end

    local transmitEventsMenuState = currentMenuState.transmitEvents
    if not transmitEventsMenuState then
        return false
    end

    -- Initilize previous RAM frame if missing
    if prevItemState == nil then
        if config.ramconfig.verbose then
            printOutput('Doing first-time item state init')
        end
        prevItemState = getTransmittableItemsState()
    end

    -- Game was just loaded, restore to previous known RAM state
    if (gameLoaded and not prevGameLoaded) then
         -- get changes to prevRAM and apply them to game RAM
        if config.ramconfig.verbose then
            printOutput('Performing save restore')
        end
        local newItemState = getTransmittableItemsState()
        local message = getItemStateChanges(newItemState, prevItemState)
        prevItemState = newItemState
        if (message) then
            ramController.processMessage('Save Restore', message)
        end
    end

    -- Load all queued changes
    while not messageQueue.isEmpty() do
        if config.ramconfig.verbose then
            printOutput('Processing incoming message')
        end
        local nextmessage = messageQueue.popLeft()
        ramController.processMessage(nextmessage.their_user, nextmessage.message)
    end

    -- Get current RAM events
    local newItemState = getTransmittableItemsState()
    local message = getItemStateChanges(prevItemState, newItemState)

    -- Update the RAM frame pointer
    prevItemState = newItemState
    prevGameLoaded = gameLoaded

    return message
end


-- Process a message from another player and update RAM
function ramController.processMessage(their_user, message)

    if message['i'] then
        message['i'] = nil -- Item splitting is not supported yet
    end

    if config.ramconfig.verbose then
        printOutput(string.format('Processing message [%s] from [%s].', asString(message), asString(their_user)))
    end
    if isGameLoadedWithFetch() then

        if config.ramconfig.verbose then
            printOutput("Game loaded. About to do the message")
        end
        prevItemState = applyItemStateChanges(prevItemState, their_user, message)
    else
        if config.ramconfig.verbose then
            printOutput("Game not loaded. Putting the message back on the queue")
        end
        messageQueue.pushRight({['their_user']=their_user, ['message']=message}) -- Put the message back in the queue so we reprocess it once the game is loaded
    end
end

local configformState

function configOK() 
    configformState = 'OK'
end
function configCancel() 
    configformState = 'Cancel'
end


function ramController.getConfig()

    configformState = 'Idle'

    forms.setproperty(mainform, 'Enabled', false)

    local configform = forms.newform(200, 220, '')
    local chkAmmo = forms.checkbox(configform, 'Ammo', 10, 10)
    local chkHealth = forms.checkbox(configform, 'Health', 10, 40)
    local chkRupees = forms.checkbox(configform, 'Rupees', 10, 70)
    local logLevelLabel = forms.label(configform, 'Messages', 10, 103, 60, 40)
    local logLevelDropdown = forms.dropdown(configform, {'Default', LOG_LEVEL_VERBOSE}, 75, 100, 100, 35)
    local btnOK = forms.button(configform, 'OK', configOK, 10, 140, 50, 23)
    local btnCancel = forms.button(configform, 'Cancel', configCancel, 70, 140, 50, 23)

    while configformState == 'Idle' do
        coroutine.yield()
    end

    local config = {
        ammo = forms.ischecked(chkAmmo),
        health = forms.ischecked(chkHealth),
        rupees = forms.ischecked(chkRupees),
        verbose = forms.gettext(logLevelDropdown) == LOG_LEVEL_VERBOSE
    }

    forms.destroy(configform)
    forms.setproperty(mainform, 'Enabled', true)

    if configformState == 'OK' then
        return config
    else
        return false
    end
end

return ramController


