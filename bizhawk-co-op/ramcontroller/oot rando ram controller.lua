
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

-- local junkItems = {
-- [1]={['val']=0x28, ['name']='Three Bombs'},
-- 	{['val']=0x34, ['name']='One Rupee'},
-- 	{['val']=0x35, ['name']='Five Rupees'},
-- 	{['val']=0x36, ['name']='Twenty Rupees'},
-- 	{['val']=0x42, ['name']='Heart'},
-- 	{['val']=0x45, ['name']='Small Magic'},
-- }


-- local gameLoadedModes = {
--     [0x00]=false,  --Triforce / Zelda startup screens
--     [0x01]=false,  --Game Select screen
--     [0x02]=false,  --Copy Player Mode
--     [0x03]=false,  --Erase Player Mode
--     [0x04]=false,  --Name Player Mode
--     [0x05]=false,  --Loading Game Mode
--     [0x06]=true,  --Pre Dungeon Mode
--     [0x07]=true,  --Dungeon Mode
--     [0x08]=true,  --Pre Overworld Mode
--     [0x09]=true,  --Overworld Mode
--     [0x0A]=true,  --Pre Overworld Mode (special overworld)
--     [0x0B]=true,  --Overworld Mode (special overworld)
--     [0x0C]=true,  --???? I think we can declare this one unused, almost with complete certainty.
--     [0x0D]=true,  --Blank Screen
--     [0x0E]=true,  --Text Mode/Item Screen/Map
--     [0x0F]=true,  --Closing Spotlight
--     [0x10]=true,  --Opening Spotlight
--     [0x11]=true,  --Happens when you fall into a hole from the OW.
--     [0x12]=true,  --Death Mode
--     [0x13]=true,  --Boss Victory Mode (refills stats)
--     [0x14]=false,  --History Mode (Title Screen Demo)
--     [0x15]=true,  --Module for Magic Mirror
--     [0x16]=true,  --Module for refilling stats after boss.
--     [0x17]=false,  --Restart mode (save and quit)
--     [0x18]=true,  --Ganon exits from Agahnim's body. Chase Mode.
--     [0x19]=true,  --Triforce Room scene
--     [0x1A]=false,  --End sequence
--     [0x1B]=false,  --Screen to select where to start from (House, sanctuary, etc.)
-- }


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
-- local prevDomain = ""
-- local function writeRAM(domain, address, size, value)
-- 	-- update domain
-- 	if (prevDomain ~= domain) then
-- 		prevDomain = domain
-- 		if not memory.usememorydomain(domain) then
-- 			return
-- 		end
-- 	end

-- 	-- default size short
-- 	if (size == nil) then
-- 		size = 2
-- 	end

-- 	if (value == nil) then
-- 		return
-- 	end

-- 	if size == 1 then
-- 		memory.writebyte(address, value)
-- 	elseif size == 2 then
-- 		memory.write_u16_be(address, value)
-- 	elseif size == 4 then
-- 		memory.write_u32_be(address, value)
-- 	end
-- end

-- -- Reads a value from RAM using little endian
-- local function readRAM(domain, address, size)
-- 	-- update domain
-- 	if (prevDomain ~= domain) then
-- 		prevDomain = domain
-- 		if not memory.usememorydomain(domain) then
-- 			return
-- 		end
-- 	end

-- 	-- default size short
-- 	if (size == nil) then
-- 		size = 2
-- 	end

-- 	if size == 1 then
-- 		return memory.readbyte(address)
-- 	elseif size == 2 then
-- 		return memory.read_u16_be(address)
-- 	elseif size == 4 then
-- 		return memory.read_u32_be(address)
-- 	end
-- end


-- Return the new value only when changing from 0
-- local function zeroChange(newValue, prevValue) 
-- 	if (newValue == 0 or (newValue ~= 0 and prevValue == 0)) then
-- 		return newValue
-- 	else
-- 		return prevValue
-- 	end
-- end

-- returns a receiveFunc that will clamp the reveived value between 0 and the value at the given pointer
local function clamp(max_pointer)

	return function(val)
		return math.max(0, math.min(max_pointer:get(), val))
	end

end
-- returns a receiveFunc that will clamp the reveived value between 0 and the given max
local function const_clamp(max_val)

	return function(val)
		return math.max(0, math.min(max_val, val))
	end

end
-- returns the value only if it has increased
local function monotonic(newValue, prevValue)
    if newValue < prevValue then
        return prevValue
    end
end

local bottle_names = {
	[ 0x14 ] = "Empty Bottle",
	[ 0x15 ] = "Red Potion",
	[ 0x16 ] = "Green Potion",
	[ 0x17 ] = "Blue Potion",
	[ 0x18 ] = "Bottled Fairy",
	[ 0x19 ] = "Fish",
	[ 0x1A ] = "Lon Lon Milk",
	[ 0x1B ] = "Rutos Letter",
	[ 0x1C ] = "Blue Fire",
	[ 0x1D ] = "Bug",
	[ 0x1E ] = "Big Poe",
	[ 0x1F ] = "Half Milk",
	[ 0x20 ] = "Poe",
}

local child_trade_name = {
	[ 0x21 ] = "Weird Egg",
	[ 0x22 ] = "Chicken",
	[ 0x23 ] = "Zeldas Letter",
	[ 0x24 ] = "Keatan Mask",
	[ 0x25 ] = "Skull Mask",
	[ 0x26 ] = "Spooky Mask",
	[ 0x27 ] = "Bunny Hood",
	[ 0x28 ] = "Goron Mask",
	[ 0x29 ] = "Zora Mask",
	[ 0x2A ] = "Gerudo Mask",
	[ 0x2B ] = "Mask of Truth",
	[ 0x2C ] = "Child Sold Out",
}

local adult_trade_name = {
	[ 0x2C ] = "Adult Sold Out",
	[ 0x2D ] = "Pocket Egg",
	[ 0x2E ] = "Pocket Cucco",
	[ 0x2F ] = "Cojiro",
	[ 0x30 ] = "Odd Mushrrom",
	[ 0x31 ] = "Odd Potion",
	[ 0x32 ] = "Poachers Saw",
	[ 0x33 ] = "Broken Sword",
	[ 0x34 ] = "Prescription",
	[ 0x35 ] = "Eyeball Frog",
	[ 0x36 ] = "Eye Drops",
	[ 0x37 ] = "Claim Check",
}

-- list of tables containing information for each shared value
local ramItems = {
	{ pointer=oot.sav:rawget('max_health'), 		type='delta' },
	{ pointer=oot.sav:rawget('cur_health'), 		type='delta', receiveFunc=clamp( oot.sav:rawget('max_health') ) },
	{ pointer=oot.sav:rawget('cur_magic'), 			type='delta', recieveFunc=clamp( oot.sav:rawget('magic_meter_size') ) },
	{ pointer=oot.sav:rawget('rupees'), 			type='delta', recieveFunc=clamp( oot.sav.equipment:rawget('wallet'):cast(oot.Implies_Max( oot.Bits(4,5), {
		[0] = 99,
		[1] = 200,
		[2] = 500,
	})))},

	-- { pointer=oot.sav:rawget('beans_purchased'), 	type='delta' },
	{ pointer=oot.sav:rawget('gold_skulltulas'),    type='delta', name="Skulltula Token" },
	{ pointer=oot.sav:rawget('heart_pieces'),   	type='delta', receiveFunc=function(newValue, prevValue) return newValue % 4 end },

	{ pointer=oot.sav:rawget('magic_meter_level'):cast( oot.Magic_Meter ), type='delta', name={ [1]="Magic", [2]="Double Magic" } },

	{ pointer=oot.sav:rawget('double_defense'), 		type='bool', name="Double Defense" },
	{ pointer=oot.sav:rawget('double_defense_hearts'),  type='num' },

	{ pointer=oot.sav.inventory:rawget('deku_sticks'):cast( oot.Settable_Item(0) ),			type='num' },
	{ pointer=oot.sav.inventory:rawget('deku_nuts'):cast( oot.Settable_Item(1) ),			type='num' },
	{ pointer=oot.sav.inventory:rawget('bombs'):cast( oot.Settable_Item(2) ),				type='num' },
	{ pointer=oot.sav.inventory:rawget('bow'):cast( oot.Settable_Item(3) ),					type='num' },
	{ pointer=oot.sav.inventory:rawget('fire_arrow'):cast( oot.Settable_Item(4) ),			type='num' },
	{ pointer=oot.sav.inventory:rawget('dins_fire'):cast( oot.Settable_Item(5) ),			type='num' },
	{ pointer=oot.sav.inventory:rawget('slingshot'):cast( oot.Settable_Item(6) ),			type='num' },
	{ pointer=oot.sav.inventory:rawget('ocarina'):cast( oot.Settable_Item(7) ),				type='deltalist', name={ {name='Ocarina Removed', value=0xFF}, {name='Fairy Ocarina', value=0x07}, {name='Ocarina of Time', value=0x08} } },
	{ pointer=oot.sav.inventory:rawget('bombchus'):cast( oot.Settable_Item(8) ),			type='num' },
	{ pointer=oot.sav.inventory:rawget('hookshot'):cast( oot.Settable_Item(9) ),			type='deltalist', name={ {name='Hookshot Removed', value=0xFF}, {name='Hookshot', value=0x0A}, {name='Longshot', value=0x0B} } },
	{ pointer=oot.sav.inventory:rawget('ice_arrow'):cast( oot.Settable_Item(10) ),			type='num' },
	{ pointer=oot.sav.inventory:rawget('farores_wind'):cast( oot.Settable_Item(11) ),		type='num' },
	{ pointer=oot.sav.inventory:rawget('boomerang'):cast( oot.Settable_Item(12) ),			type='num' },
	{ pointer=oot.sav.inventory:rawget('lens_of_truth'):cast( oot.Settable_Item(13) ),		type='num' },
	{ pointer=oot.sav.inventory:rawget('magic_beans'):cast( oot.Settable_Item(14) ),		type='num' },
	{ pointer=oot.sav.inventory:rawget('megaton_hammer'):cast( oot.Settable_Item(15) ),		type='num' },
	{ pointer=oot.sav.inventory:rawget('light_arrow'):cast( oot.Settable_Item(16) ),		type='num' },
	{ pointer=oot.sav.inventory:rawget('nayrus_love'):cast( oot.Settable_Item(17) ),		type='num' },
	{ pointer=oot.sav.inventory:rawget('bottle1'):cast( oot.Settable_Item(18) ),			type='num', name=bottle_names },
	{ pointer=oot.sav.inventory:rawget('bottle2'):cast( oot.Settable_Item(19) ),			type='num', name=bottle_names },
	{ pointer=oot.sav.inventory:rawget('bottle3'):cast( oot.Settable_Item(20) ),			type='num', name=bottle_names },
	{ pointer=oot.sav.inventory:rawget('bottle4'):cast( oot.Settable_Item(21) ),			type='num', name=bottle_names },
	{ pointer=oot.sav.inventory:rawget('adult_trade'):cast( oot.Settable_Item(22) ),		type='num', name=adult_trade },
	{ pointer=oot.sav.inventory:rawget('child_trade'):cast( oot.Settable_Item(23) ),		type='num', name=child_trade },

	{ pointer=oot.sav.ammo:rawget('deku_sticks'),	type='delta', recieveFunc=clamp( oot.sav.equipment:rawget('stick_capacity'):cast(oot.Implies_Max(oot.Bits(1,2), {
		[0] = 10,
		[1] = 10,
		[2] = 20,
		[2] = 30,
	})))},
	{ pointer=oot.sav.ammo:rawget('deku_nuts'),		type='delta', recieveFunc=clamp( oot.sav.equipment:rawget('nut_capacity'):cast(oot.Implies_Max(oot.Bits(4,5), {
		[0] = 20,
		[1] = 20,
		[2] = 30,
		[2] = 40,
	})))},
	{ pointer=oot.sav.ammo:rawget('bombs'),			type='delta', recieveFunc=clamp( oot.sav.equipment:rawget('bomb_bag'):cast(oot.Implies_Max(oot.Bits(3,4), {
		[0] = 0,
		[1] = 20,
		[2] = 30,
		[2] = 40,
	})))},
	{ pointer=oot.sav.ammo:rawget('bow'),			type='delta', recieveFunc=clamp( oot.sav.equipment:rawget('quiver'):cast(oot.Implies_Max(oot.Bits(0,1), {
		[0] = 0,
		[1] = 30,
		[2] = 40,
		[2] = 50,
	})))},
	{ pointer=oot.sav.ammo:rawget('slingshot'),		type='delta', recieveFunc=clamp( oot.sav.equipment:rawget('bullet_bag'):cast(oot.Implies_Max(oot.Bits(6,7), {
		[0] = 0,
		[1] = 30,
		[2] = 40,
		[2] = 50,
	})))},
	{ pointer=oot.sav.ammo:rawget('bombchus'),		type='delta', recieveFunc=const_clamp(50) },
	-- { pointer=oot.sav.ammo:rawget('magic_beans'),	type='delta' },

	{ pointer=oot.sav.equipment:rawget('kokiri_tunic'),			type='bool', name="Kokiri Tunic" }, -- TODO: settable equipment
	{ pointer=oot.sav.equipment:rawget('goron_tunic'),			type='bool', name="Goron Tunic" },
	{ pointer=oot.sav.equipment:rawget('zora_tunic'),			type='bool', name="Zora Tunic" },
	{ pointer=oot.sav.equipment:rawget('kokiri_boots'),			type='bool', name="Kokiri Boots" },
	{ pointer=oot.sav.equipment:rawget('iron_boots'),			type='bool', name="Iron Boots" },
	{ pointer=oot.sav.equipment:rawget('hover_boots'),			type='bool', name="Hover Boots" },
	{ pointer=oot.sav.equipment:rawget('kokiri_sword'),			type='bool', name="Kokiri Sword" },
	{ pointer=oot.sav.equipment:rawget('master_sword'),			type='bool', name="Master Sword" },
	{ pointer=oot.sav.equipment:rawget('biggoron_sword'),		type='bool', name="Biggoron Sword" },
	{ pointer=oot.sav.equipment:rawget('broken_sword_icon'),	type='bool' },
	{ pointer=oot.sav.equipment:rawget('kokiri_shield'),		type='bool', name="Kokiri Shield" },
	{ pointer=oot.sav.equipment:rawget('hylian_shield'),		type='bool', name="Hylian Shield" },
	{ pointer=oot.sav.equipment:rawget('mirror_shield'),		type='bool', name="Mirror Shield" },
	{ pointer=oot.sav:rawget('biggoron_sword_durable'), 		type='bool' },

	{ pointer=oot.sav.equipment:rawget('stick_capacity'),	type='delta', name={ [1]="Deku Sticks", [2]="20 Deku Sticks", [3]="30 Deku Sticks" } },
	{ pointer=oot.sav.equipment:rawget('nut_capacity'),		type='delta', name={ [1]="Deku Nuts", [2]="30 Nuts", [3]="40 Nuts" } },
	{ pointer=oot.sav.equipment:rawget('scale'),			type='delta', name={ [1]="Silver Scale", [2]="Golden Scale"} },
	{ pointer=oot.sav.equipment:rawget('wallet'),			type='delta', name={ [1]="Adult's Wallet", [2]="Giant's Wallet"} },
	{ pointer=oot.sav.equipment:rawget('bullet_bag'),		type='delta', name={ [1]="Bullet Seed Bag", [2]="Bigger Bullet Seed Bag", [3]="Biggest Bullet Seed Bag"} },
	{ pointer=oot.sav.equipment:rawget('quiver'),			type='delta', name={ [1]="Quiver", [2]="Bigger Quiver", [3]="Biggest Quiver"} },
	{ pointer=oot.sav.equipment:rawget('bomb_bag'),			type='delta', name={ [1]="Bomb Bag", [2]="Bigger Bomb Bag", [3]="Biggest Bomb Bag"} },
	{ pointer=oot.sav.equipment:rawget('strength'),			type='delta', name={ [1]="Goron Bracelet", [2]="Silver Gauntlets", [3]="Golden Gauntlets"} },

	{ pointer=oot.sav.quest_status:rawget('forest_medallion'),		type='bool', name="Forest Medallion" },
	{ pointer=oot.sav.quest_status:rawget('fire_medallion'),		type='bool', name="Fire Medallion" },
	{ pointer=oot.sav.quest_status:rawget('water_medallion'),		type='bool', name="Water Medallion" },
	{ pointer=oot.sav.quest_status:rawget('spirit_medallion'),		type='bool', name="Spirit Medallion" },
	{ pointer=oot.sav.quest_status:rawget('shadow_medallion'),		type='bool', name="Shadow Medallion" },
	{ pointer=oot.sav.quest_status:rawget('light_medallion'),		type='bool', name="Light Medallion" },
	{ pointer=oot.sav.quest_status:rawget('minuet_of_forest'),		type='bool', name="Minuet of Forest" },
	{ pointer=oot.sav.quest_status:rawget('bolero_of_fire'),		type='bool', name="Bolero of Fire" },
	{ pointer=oot.sav.quest_status:rawget('seranade_of_water'),		type='bool', name="Seranade of Water" },
	{ pointer=oot.sav.quest_status:rawget('requiem_of_spirit'),		type='bool', name="Requiem of Spirit" },
	{ pointer=oot.sav.quest_status:rawget('nocturne_of_shadow'),	type='bool', name="Nocturne of Shadow" },
	{ pointer=oot.sav.quest_status:rawget('prelude_of_light'),		type='bool', name="Prelude of Light" },
	{ pointer=oot.sav.quest_status:rawget('zeldas_lullaby'),		type='bool', name="Zelda's Lullaby" },
	{ pointer=oot.sav.quest_status:rawget('eponas_song'),			type='bool', name="Epona's Song" },
	{ pointer=oot.sav.quest_status:rawget('sarias_song'),			type='bool', name="Sarias Song" },
	{ pointer=oot.sav.quest_status:rawget('suns_song'),				type='bool', name="Sun's Song" },
	{ pointer=oot.sav.quest_status:rawget('song_of_time'),			type='bool', name="Song of Time" },
	{ pointer=oot.sav.quest_status:rawget('song_of_storms'),		type='bool', name="Song of Storms" },
	{ pointer=oot.sav.quest_status:rawget('kokiri_emerald'),		type='bool', name="Kokiri Emerald" },
	{ pointer=oot.sav.quest_status:rawget('goron_ruby'),			type='bool', name="Goron Ruby" },
	{ pointer=oot.sav.quest_status:rawget('zora_sapphire'),			type='bool', name="Zora Sapphire" },
	{ pointer=oot.sav.quest_status:rawget('stone_of_agony'),		type='bool', name="Stone of Agony" },
	{ pointer=oot.sav.quest_status:rawget('gerudo_card'),			type='bool' },
	{ pointer=oot.sav.quest_status:rawget('skulltula_icon'),		type='bool' },

	{ pointer=oot.sav.dungeon_items.forest_temple:rawget('boss_key'),			type='bool', name="Forest Temple Boss Key" },
	{ pointer=oot.sav.dungeon_items.fire_temple:rawget('boss_key'),				type='bool', name="Fire Temple Boss Key" },
	{ pointer=oot.sav.dungeon_items.water_temple:rawget('boss_key'),			type='bool', name="Water Temple Boss Key" },
	{ pointer=oot.sav.dungeon_items.spirit_temple:rawget('boss_key'),			type='bool', name="Spirit Temple Boss Key" },
	{ pointer=oot.sav.dungeon_items.shadow_temple:rawget('boss_key'),			type='bool', name="Shadow Temple Boss Key" },
	{ pointer=oot.sav.dungeon_items.ganons_tower:rawget('boss_key'),			type='bool', name="Ganon's Tower Boss Key" },

	{ pointer=oot.sav.dungeon_items.deku_tree:rawget('compass'),			type='bool', name="Deku Tree Compass" },
	{ pointer=oot.sav.dungeon_items.dodongos_cavern:rawget('compass'),		type='bool', name="Dodongo's Cavern Compass" },
	{ pointer=oot.sav.dungeon_items.jabu_jabus_belly:rawget('compass'),		type='bool', name="Jabu Jabu's Belly Compass" },
	{ pointer=oot.sav.dungeon_items.forest_temple:rawget('compass'),		type='bool', name="Forest Temple Compass" },
	{ pointer=oot.sav.dungeon_items.fire_temple:rawget('compass'),			type='bool', name="Fire Temple Compass" },
	{ pointer=oot.sav.dungeon_items.water_temple:rawget('compass'),			type='bool', name="Water Temple Compass" },
	{ pointer=oot.sav.dungeon_items.spirit_temple:rawget('compass'),		type='bool', name="Spirit Temple Compass" },
	{ pointer=oot.sav.dungeon_items.shadow_temple:rawget('compass'),		type='bool', name="Shadow Temple Compass" },
	{ pointer=oot.sav.dungeon_items.bottom_of_the_well:rawget('compass'),	type='bool', name="Bottom of the Well Compass" },
	{ pointer=oot.sav.dungeon_items.ice_cavern:rawget('compass'),			type='bool', name="Ice Cavern Compass" },

	{ pointer=oot.sav.dungeon_items.deku_tree:rawget('map'),			type='bool', name="Deku Tree Map" },
	{ pointer=oot.sav.dungeon_items.dodongos_cavern:rawget('map'),		type='bool', name="Dodongo's Cavern Map" },
	{ pointer=oot.sav.dungeon_items.jabu_jabus_belly:rawget('map'),		type='bool', name="Jabu Jabu's Belly Map" },
	{ pointer=oot.sav.dungeon_items.forest_temple:rawget('map'),		type='bool', name="Forest Temple Map" },
	{ pointer=oot.sav.dungeon_items.fire_temple:rawget('map'),			type='bool', name="Fire Temple Map" },
	{ pointer=oot.sav.dungeon_items.water_temple:rawget('map'),			type='bool', name="Water Temple Map" },
	{ pointer=oot.sav.dungeon_items.spirit_temple:rawget('map'),		type='bool', name="Spirit Temple Map" },
	{ pointer=oot.sav.dungeon_items.shadow_temple:rawget('map'),		type='bool', name="Shadow Temple Map" },
	{ pointer=oot.sav.dungeon_items.bottom_of_the_well:rawget('map'),	type='bool', name="Bottom of the Well Map" },
	{ pointer=oot.sav.dungeon_items.ice_cavern:rawget('map'),			type='bool', name="Ice Cavern Map" },

	{ pointer=oot.sav.small_keys:rawget('forest_temple'):cast( oot.Key ),			type='delta', name="Forest Temple Small Key", recieveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('fire_temple'):cast( oot.Key ),				type='delta', name="Fire Temple Small Key", recieveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('water_temple'):cast( oot.Key ),			type='delta', name="Water Temple Small Key", recieveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('spirit_temple'):cast( oot.Key ),			type='delta', name="Spirit Temple Small Key", recieveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('shadow_temple'):cast( oot.Key ),			type='delta', name="Shadow Temple Small Key", recieveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('bottom_of_the_well'):cast( oot.Key ),		type='delta', name="Bottom of the Well Small Key", recieveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('gerudo_training_ground'):cast( oot.Key ),	type='delta', name="Gerudo Training Ground Small Key", recieveFunc=monotonic },
	-- { pointer=oot.sav.small_keys:rawget('thieves_hideout'),		type='delta', name="Gerudo Fortress Small Key", recieveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('inside_ganons_castle'):cast( oot.Key ),	type='delta', name="Ganon's Castle Small Key", recieveFunc=monotonic },

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
		local ramval = item.pointer:get()
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
			-- If delta, get the change from prevRAM frame
			elseif ramItems[address].type == "delta" then
				ramevents[address] = val - prevRAM[address]
				changes = true
			elseif ramItems[address].type == "deltalist" then
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
		-- If delta, add to the previous value
		elseif ramItems[address].type == "delta" then
			newval = prevRAM[address] + val
		elseif ramItems[address].type == "deltalist" then
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

		-- Write the new value
		getGUImessage(address, prevRAM[address], newval, their_user)
		prevRAM[address] = newval
		if gameLoadedModes[gameMode] then
			ramItems[address].pointer:set(newval)
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
oot_rom.itemcount = #locations


local splitItems = {}
local function removeItems()
	-- -- Reload Core to restore previously removed items
	-- client.reboot_core()
	-- prevDomain = ""

	-- local junkItemsCount = tableCount(junkItems)
	-- math.randomseed(os.time())
	-- math.random(junkItemsCount)

	-- for ID, location in pairs(locations) do
	-- 	-- Remove item if it's not yours
	-- 	if (splitItems[ID] ~= my_ID) then
	-- 		local oldVal = readRAM("CARTROM", location.address, 1)
	-- 		-- Remove Item, Fill with junk
	-- 		writeRAM("CARTROM", location.address, 1, junkItems[math.random(junkItemsCount)].val)
	-- 	end
	-- end
end

client.reboot_core()
local prevDomain = ""


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
	-- gameMode = readRAM("WRAM", 0x0010, 1)
	-- local gameLoaded = gameLoadedModes[gameMode] == true

	-- Don't check for updated when game is not running
	-- if not gameLoaded then
	-- 	prevGameMode = gameMode
	-- 	return false
	-- end

	-- Initilize previous RAM frame if missing
	if prevRAM == nil then
		prevRAM = getRAM()
	end

	-- Checked for queued death and apply when safe
	-- if tableCount(deathQueue) > 0 and not deathQueue[config.user] then
	-- 	-- Main mode: 07 = Dungeon, 09 = Overworld, 0B = Special Overworld
	-- 	-- Sub mode: Non 0 = game is paused, transitioning between modes
	-- 	if (gameMode == 0x07 or gameMode == 0x09 or gameMode == 0x0B) and (readRAM("WRAM", 0x0011, 1) == 0x00) then 
	-- 		-- If link is controllable
	-- 		writeRAM("WRAM", 0x0010, 2, 0x0012) -- Kill link as soon as it's safe
	-- 		writeRAM("WRAM", 0xF36D, 1, 0)
	-- 		writeRAM("WRAM", 0x04C6, 1, 0) -- Stop any special cutscenes
	-- 		prevRAM[0xF36D] = 0
	-- 		gameMode = 0x12
	-- 	end
	-- end

	-- if gameMode == 0x12 then
	-- 	local deathCount = tableCount(deathQueue)
	-- 	if (deathCount > 0 and deathCount < playercount) then
	-- 		-- Lock the death until everyone is dying
	-- 		writeRAM("WRAM", 0x0010, 2, 0x0012)
	-- 	elseif (deathCount >= playercount) then
	-- 		deathQueue = {}

	-- 		local hasFairy = false
	-- 		for bottleID=0,3 do
	-- 			if prevRAM[0xF35C + bottleID] == 0x06 then
	-- 				-- has fairy
	-- 				hasFairy = true
	-- 			end
	-- 		end

	-- 		local maxHP = readRAM("WRAM", 0xF36C, 1)
	-- 		local contHP
	-- 		if (hasFairy) then
	-- 			contHP = 7 * 8
	-- 		else
	-- 		 	contHP = (continueHP[maxHP / 8] or 10) * 8
	-- 		end
	-- 		prevRAM[0xF36D] = math.max(math.min(prevRAM[0xF36D] + contHP, maxHP), 0)
	-- 		writeRAM("WRAM", 0xF36D, 1, prevRAM[0xF36D])		
	-- 	end

	-- 	if (prevGameMode == 0x12) then
	-- 		-- discard continue HP/fairy HP
	-- 		writeRAM("WRAM", 0xF36D, 1, prevRAM[0xF36D])
	-- 	end
	-- end

	-- -- Game was just loaded, restore to previous known RAM state
	-- if (gameLoaded and not gameLoadedModes[prevGameMode]) then
	-- 	 -- get changes to prevRAM and apply them to game RAM
	-- 	local newRAM = getRAM()
	-- 	local message = eventRAMchanges(newRAM, prevRAM)
	-- 	prevRAM = newRAM
	-- 	if (message) then
	-- 		oot_rom.processMessage("Save Restore", message)
	-- 	end
	-- end

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

	-- -- Check for death message
	-- if gameMode == 0x12 then
	-- 	if (prevGameMode ~= 0x12) then
	-- 		if message == false then
	-- 			message = {}
	-- 		end

	-- 		message[0xF36D] = -0x100 -- death message is a large HP loss
	-- 		deathQueue[config.user] = true
	-- 	else 
	-- 		-- suppress all non death messages during death sequence
	-- 		return false
	-- 	end
	-- end
	-- prevGameMode = gameMode

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

	--if gameLoadedModes[gameMode] then
		prevRAM = setRAMchanges(prevRAM, their_user, message)
	--else
	--	messageQueue.pushRight({["their_user"]=their_user, ["message"]=message})
	--end
end

setmetatable(_G, old_global_metatable)

return oot_rom
