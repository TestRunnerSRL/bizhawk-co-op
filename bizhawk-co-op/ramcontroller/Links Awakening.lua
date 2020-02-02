local NO_ITEM_VALUE = 0x00

local MAX_NUM_HEART_CONTAINERS = 0x0E -- 14
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

-- All inventory item transmissions are done over the B-item address, since items could appear/disappear from other
-- inventory slots as players equip.
-- Assumption: Only one inventory item may be acquired in a single transmission interval
local B_SLOT_ADDR = 0xDB00

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

local gameStateAddr = 0xDB95
-- Source https://github.com/zladx/LADX-Disassembly/blob/4ae748bd354f94ed2887f04d4014350d5a103763/src/constants/gameplay.asm#L22-L48
local gameStateVals = { -- Only states where we can do events are listed
    [0x07] = 'Map Screen',
    [0x0B] = 'Main Gameplay',
    [0x0C] = 'Inventory Screen',
}

local menuStateAddr = 0xDB9A
local menuStateVals = {
    [0x00] = {desc = 'Pause Menu', transmitEvents = false}, -- TODO change this for inventory insanity
    [0x80] = {desc = 'Game running/Title Screen Running', transmitEvents = true},
    [0xFF] = {desc = 'Death/Save+Quit Menu', transmitEvents = false}, 
}

function isGameLoaded(gameStateVal)
    return gameStateVals[gameStateVal] ~= nil
end

function isGameLoadedWithFetch() -- Grr. Why doesn't lua support function overloading??
    return isGameLoaded(readRAM(gameStateAddr))
end

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
local dying = false
local prevmode = 0
local ramController = {}
local playercount = 1
local possessedInventoryItems = {}

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

function giveInventoryItem(itemVal)

    local firstEmptySLotAddr = nil

    for _, slotInfo in ipairs(inventorySlotInfos) do
        local slotAddr = slotInfo['address']
        local thisSlotsItem = readRAM(slotAddr, 1)
        if thisSlotsItem == itemVal then
            return -- We already have this item
        end
        if thisSlotsItem == NO_ITEM_VALUE then
            firstEmptySLotAddr = slotAddr
            return
        end
    end

    if not firstEmptySLotAddr then
        console.log(string.format('ERROR: Attempt to award item %s, but all inventory slots are full!', inventoryItemVals[itemVal]))
        return
    end

    writeRAM(firstEmptySLotAddr, 1, itemVal)
end

local ramItemAddrs = {
    [0xDB0C] = {name = 'Flippers', type = 'bool'},
    [0xDB0D] = {name = 'Potion', type = 'bool'},
    [0xDB0E] = {name = 'Trading Item', type = 'num', maxVal = MAX_TRADING_ITEM},
    [0xDB0F] = {name = 'Number of secret shells', type = 'num'},
    [0xDB10] = {name = 'Slime Key', type = 'bool'},
    [0xDB11] = {name = 'Tail Key', type = 'bool'},
    [0xDB12] = {name = 'Angler Key', type = 'bool'},
    [0xDB13] = {name = 'Face Key', type = 'bool'},
    [0xDB14] = {name = 'Birdie Key', type = 'bool'},
    [0xDB15] = {name = 'Number of golden leaves', type = 'num', maxVal = MAX_GOLDEN_LEAVES},
    [0xDB43] = {name = 'Power bracelet level', type = 'num', maxVal = MAX_BRACELET_LEVEL},
    [0xDB44] = {name = 'Shield level', type = 'num', maxVal = MAX_SHIELD_LEVEL},
    [0xDB45] = {name = 'Number of arrows', type = 'num', flag = 'ammo'},
    [0xDB49] = {name = {
        [0] = 'unknown song',
        [1] = 'unknown song',
        [2] = 'unknown song',
        [3] = 'unknown song',
        [4] = 'unknown song',
        [5] = 'Ballad of the Wind Fish',
        [6] = 'Manbo Mambo',
        [7] = 'Frog\'s Song of Soul',
    }, type = 'bitmask'},
    [0xDB4A] = {name = 'Ocarina selected song', type = 'num'},
    [0xDB4C] = {name = 'Magic powder quantity', type = 'num', flag = 'ammo'},
    [0xDB4D] = {name = 'Number of bombs', type = 'num', flag = 'ammo'},
    [0xDB4E] = {name = 'Sword level', type = 'num', maxVal = MAX_SWORD_LEVEL},
--    DB56-DB58 Number of times the character died for each save slot (one byte per save slot)
    [0xDB5A] = {name = 'Current health', type = 'num', flag = 'life'}, --Each increment of 08 is one full heart, each increment of 04 is one-half heart
    [0xDB5B] = {name = 'Maximum health', type = 'num', maxVal = MAX_NUM_HEART_CONTAINERS}, --Max recommended value is 0E (14 hearts)
    [0xDB5D] = {name = 'Rupees', type = 'num', flag = 'money', size = 2}, --2 bytes, decimal value
    [0xDB76] = {name = 'Max magic powder', type = 'num'},
    [0xDB77] = {name = 'Max bombs', type = 'num'},
    [0xDB78] = {name = 'Max arrows', type = 'num'},
--    [0xDBAE] = {name = 'Dungeon map grid position', type = 'num'},
    [0xDBD0] = {name = 'Keys possessed', type = 'num'},
    [0xDB16] = {name = 'Tail Cave', type = 'dungeonFlags'}, -- 5 byte sections (Map bool, compass bool, beak bool, nightmare key bool, key num)
    [0xDB1B] = {name = 'Bottle Grotto', type = 'dungeonFlags'},
    [0xDB20] = {name = 'Key Cavern', type = 'dungeonFlags'},
    [0xDB25] = {name = 'Angler\'s Tunnel', type = 'dungeonFlags'},
    [0xDB2A] = {name = 'Catfish\'s Maw', type = 'dungeonFlags'},
    [0xDB2F] = {name = 'Face Shrine', type = 'dungeonFlags'},
    [0xDB34] = {name = 'Eagle\'s Tower', type = 'dungeonFlags'},
    [0xDB39] = {name = 'Turtle Rock', type = 'dungeonFlags'},
    [0xDB65] = {name = 'Tail Cave', type = 'dungeonState', instrumentName = 'Full Moon Cello'}, -- 00=starting state, 01=defeated miniboss, 02=defeated boss, 03=have instrument
    [0xDB66] = {name = 'Bottle Grotto', type = 'num', instrumentName = 'Conch Horn'},
    [0xDB67] = {name = 'Key Cavern', type = 'num', instrumentName = 'Sea Lily\'s Bell'},
    [0xDB68] = {name = 'Angler\'s Tunnel', type = 'num', instrumentName = 'Surf Harp'},
    [0xDB69] = {name = 'Catfish\'s Maw', type = 'num', instrumentName = 'Wind Marimba'},
    [0xDB6A] = {name = 'Face Shrine', type = 'num', instrumentName = 'Coral Triangle'},
    [0xDB6B] = {name = 'Eagle\'s Tower', type = 'num', instrumentName = 'Organ of Evening Calm'},
    [0xDB6C] = {name = 'Turtle Rock', type = 'num', instrumentName = 'Thunder Drum'},
}

for _, slotInfo in pairs(inventorySlotInfos) do
    ramItemAddrs[slotInfo['address']] = {name = slotInfo['name'], type = 'Inventory Slot'}
end


function promoteItem(list, newItem) -- TODO
    local index
    if (list[newItem] == nil) then
        index = math.huge
    else
        index = list[newItem]
    end

    local count = 0
    for item,val in pairs(list) do
        count = count + 1
        if (val < index) then
            list[item] = val + 1
        end
    end

    list[newItem] = 0

    if index == math.huge then
        return count
    else
        return index
    end
end


-- Display a message of the ram event
function getGUImessage(address, prevVal, newVal, user)
    -- Only display the message if there is a name for the address
    local name = ramItemAddrs[address].name
    if name and prevVal ~= newVal then

        local itemType = ramItemAddrs[address].type

        -- If boolean, show 'Removed' for false
        if itemType == 'bool' then
            gui.addmessage(user .. ': ' .. name .. (newVal == 0 and 'Removed' or ''))

        -- If numeric, show the indexed name or name with value
        elseif itemType == 'num' then
            if (type(name) == 'string') then
                gui.addmessage(user .. ': ' .. name .. ' = ' .. newVal)
            elseif (name[newVal]) then
                gui.addmessage(user .. ': ' .. name[newVal])
            end

        -- If bitflag, show each bit: the indexed name or bit index as a boolean
        elseif itemType == 'bitmask' then
            for b=0,7 do
                local newBit = bit.check(newVal, b)
                local prevBit = bit.check(prevVal, b)

                if (newBit ~= prevBit) then
                    if (type(name) == 'string') then
                        gui.addmessage(user .. ': ' .. name .. ' flag ' .. b .. (newBit and '' or ' Removed'))
                    elseif (name[b]) then
                        gui.addmessage(user .. ': ' .. name[b] .. (newBit and '' or ' Removed'))
                    end
                end
            end

        -- If an inventory item, just show the inventory item name
        elseif ram == 'Inventory Slot' then
            gui.addmessage(user .. ': ' .. inventoryItemVals[newVal])
        else 
            gui.addmessage('Unknown item ram type')
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

        if not skip then
            -- Default byte length to 1
            if (not item.size) then
                item.size = 1
            end

            local ramval = readRAM(address, item.size)

            transmittableTable[address] = ramval
        end
    end

    return transmittableTable
end


-- Get a list of changed ram events
function getItemStateChanges(prevState, newState)
    local ramevents = {}
    local changes = false

    for address, val in pairs(newState) do
        -- If change found
        if (prevState[address] ~= val) then

            if config.ramconfig.verbose then
                printOutput(string.format('Updating address [%s] to value [%s].', asString(address), asString(val)))
            end
            getGUImessage(address, prevState[address], val, config.user)

            local itemType = ramItemAddrs[address].type

            -- If boolean, get T/F
            if itemType == 'bool' then
                ramevents[address] = (val ~= 0)
                changes = true
            -- If numeric, get value
            elseif itemType == 'num' then
                ramevents[address] = val
                changes = true
            -- If bitmask, get the changed bits
            elseif itemType == 'bitmask' then
                local changedBits = {}
                for b=0,7 do
                    local newBit = bit.check(val, b)
                    local prevBit = bit.check(prevState[address], b)

                    if (newBit ~= prevBit) then
                        changedBits[b] = newBit
                    end
                end
                ramevents[address] = changedBits
                changes = true
            elseif itemType == 'Inventory Slot' then
                -- Do nothing. We do a separate check for new inventory items below
            else 
                console.log(string.format('Unknown item type [%s] for item %s (Address: %s)', itemType, ramItemAddrs[address].name, address))
            end
        end
    end

    local prevPossessedItems = getPossessedItemsTable(prevState)
    local newPossessedItems = getPossessedItemsTable(newState)

    for itemVal, isPrevPossessed in pairs(prevPossessedItems) do
        local isNewPossessed = newPossessedItems[itemVal]
        if not isPrevPossessed and isNewPossessed then
            if config.ramconfig.verbose then
                printOutput(string.format('Discovered that item [%s] is newly possessed.', itemVal))
            end
            changes = true
            if ramevents[B_SLOT_ADDR] then -- Log an error if the assumption that only one item can be acquired at a time is violated
                local existingItemName = inventoryItemVals[ramevents[B_SLOT_ADDR]]
                local refusedItemName = inventoryItemVals[itemVal]
                error(string.format("Error: Multiple items were acquired simultaneously. Already transmitting [%s]. Unable to transmit [%s]. ", existingItemName, refusedItemName))
            else
                ramevents[B_SLOT_ADDR] = itemVal
            end
        end
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
    for address, val in pairs(newEvents) do
        local newval

        if config.ramconfig.verbose then
            printOutput(string.format('Applying state change [%s=%s]', asString(address), asString(val)))
        end
        -- If boolean type value
        if ramItemAddrs[address].type == 'bool' then
            newval = (val and 1 or 0) -- Coercing booleans back to 1 or 0 numeric
        -- If numeric type value
        elseif ramItemAddrs[address].type == 'num' then
            newval = val
        -- If bitflag update each bit
        elseif ramItemAddrs[address].type == 'bit' then
            newval = prevRAM[address]
            for b, bitval in pairs(val) do
                if bitval then
                    newval = bit.set(newval, b)
                else
                    newval = bit.clear(newval, b)
                end
            end
        elseif address == B_SLOT_ADDR then
            giveInventoryItem(val)
        else 
            printOutput(string.format('Unknown item type [%s] for item %s (Address: %s)', itemType, ramItemAddrs[address].name, address))
            newval = prevRAM[address]
        end

        -- Write the new value
        getGUImessage(address, prevRAM[address], newval, their_user)
        prevRAM[address] = newval
        local gameLoaded = isGameLoadedWithFetch()
        if gameLoaded then
            writeRAM(address, ramItemAddrs[address].size, newval)
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
        printOutput("Game loaded. About to do the message")
        prevItemState = applyItemStateChanges(prevItemState, their_user, message)
    else
        printOutput("Game not loaded. Putting the message back on the queue")
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

    local configform = forms.newform(200, 190, '')
    local chkAmmo = forms.checkbox(configform, 'Ammo', 10, 10)
    local chkHealth = forms.checkbox(configform, 'Health', 10, 40)
    local logLevelLabel = forms.label(configform, 'Messages', 10, 73, 60, 40)
    local logLevelDropdown = forms.dropdown(configform, {'Default', LOG_LEVEL_VERBOSE}, 75, 70, 100, 35)
    local btnOK = forms.button(configform, 'OK', configOK, 10, 110, 50, 23)
    local btnCancel = forms.button(configform, 'Cancel', configCancel, 70, 110, 50, 23)

    while configformState == 'Idle' do
        coroutine.yield()
    end

    local config = {
        ammo = forms.ischecked(chkAmmo),
        health = forms.ischecked(chkHealth),
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


