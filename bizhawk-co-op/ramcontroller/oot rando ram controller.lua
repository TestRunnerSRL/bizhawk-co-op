
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

local junkItems = {
[1]={['val']=0x4C, ['name']='Green Rupee'},
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
    return newValue
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

-- TODO: death/fairys
-- TODO: skulltulas

local function receiveHealth(newValue, prevValue, address, item, their_user)
	-- local delta = newValue - prevValue

	-- if (tableCount(deathQueue) > 0) then
	-- 	if (delta < -0x1FF) then
	-- 		deathQueue[their_user] = true
	-- 	end
	-- 	return prevValue
	-- end

	-- if (delta < -0x1FF) then
	-- 	-- death message
	-- 	newValue = 0
	-- 	gui.addmessage(their_user .. " killed you.")
	-- 	deathQueue[their_user] = true
	-- end

	newValue = clamp( oot.sav:rawget('max_health') )(newValue)

	return newValue
end

-- list of tables containing information for each shared value
local ramItems = {
	{ pointer=oot.sav:rawget('max_health'), 		type='delta' },
	['chp']={ pointer=oot.sav:rawget('cur_health'), type='delta', receiveFunc=receiveHealth },
	{ pointer=oot.sav:rawget('cur_magic'), 			type='delta', receiveFunc=clamp( oot.sav:rawget('magic_meter_size') ) },
	{ pointer=oot.sav:rawget('rupees'), 			type='delta', receiveFunc=clamp( oot.sav.equipment:rawget('wallet'):cast(oot.Implies_Max( oot.Bits(4,5), {
		[0] = 99,
		[1] = 200,
		[2] = 500,
	})))},

	-- { pointer=oot.sav:rawget('beans_purchased'), 	type='delta' },
	['skc']={ pointer=oot.sav:rawget('gold_skulltulas'),    type='tokencount' },
	{ pointer=oot.sav:rawget('heart_pieces'),   	type='delta', receiveFunc=function(newValue, prevValue) return newValue % 4 end },

	{ pointer=oot.sav:rawget('magic_meter_level'):cast( oot.Magic_Meter ), type='delta', name={ [1]="Magic", [2]="Double Magic" } },

	{ pointer=oot.sav:rawget('double_defense'), 		type='bool', name="Double Defense" },
	{ pointer=oot.sav:rawget('double_defense_hearts'),  type='num' },

	{ pointer=oot.sav.inventory:rawget('deku_sticks'):cast( oot.Settable_Item(0) ),			type='num' },
	{ pointer=oot.sav.inventory:rawget('deku_nuts'):cast( oot.Settable_Item(1) ),			type='num' },
	{ pointer=oot.sav.inventory:rawget('bombs'):cast( oot.Settable_Item(2) ),				type='num' },
	{ pointer=oot.sav.inventory:rawget('bow'):cast( oot.Settable_Item(3) ),					type='num', name="Bow" },
	{ pointer=oot.sav.inventory:rawget('fire_arrow'):cast( oot.Settable_Item(4) ),			type='num', name="Fire Arrow" },
	{ pointer=oot.sav.inventory:rawget('dins_fire'):cast( oot.Settable_Item(5) ),			type='num', name="Din's Fire" },
	{ pointer=oot.sav.inventory:rawget('slingshot'):cast( oot.Settable_Item(6) ),			type='num', name="slingshot" },
	{ pointer=oot.sav.inventory:rawget('ocarina'):cast( oot.Settable_Item(7) ),				type='deltalist', name={ {name='Ocarina Removed', value=0xFF}, {name='Fairy Ocarina', value=0x07}, {name='Ocarina of Time', value=0x08} } },
	{ pointer=oot.sav.inventory:rawget('bombchus'):cast( oot.Settable_Item(8) ),			type='num', name="Bombchus" },
	{ pointer=oot.sav.inventory:rawget('hookshot'):cast( oot.Settable_Item(9) ),			type='deltalist', name={ {name='Hookshot Removed', value=0xFF}, {name='Hookshot', value=0x0A}, {name='Longshot', value=0x0B} } },
	{ pointer=oot.sav.inventory:rawget('ice_arrow'):cast( oot.Settable_Item(10) ),			type='num', name="Ice Arrow" },
	{ pointer=oot.sav.inventory:rawget('farores_wind'):cast( oot.Settable_Item(11) ),		type='num', name="Farore's Wind" },
	{ pointer=oot.sav.inventory:rawget('boomerang'):cast( oot.Settable_Item(12) ),			type='num', name="Boomerang" },
	{ pointer=oot.sav.inventory:rawget('lens_of_truth'):cast( oot.Settable_Item(13) ),		type='num', name="Lens of Truth" },
	-- { pointer=oot.sav.inventory:rawget('magic_beans'):cast( oot.Settable_Item(14) ),		type='num', name="Magic Beans" },
	{ pointer=oot.sav.inventory:rawget('megaton_hammer'):cast( oot.Settable_Item(15) ),		type='num', name="Megaton Hammer" },
	{ pointer=oot.sav.inventory:rawget('light_arrow'):cast( oot.Settable_Item(16) ),		type='num', name="Light Arrow" },
	{ pointer=oot.sav.inventory:rawget('nayrus_love'):cast( oot.Settable_Item(17) ),		type='num', name="Nayru's Love" },
	{ pointer=oot.sav.inventory:rawget('bottle1'):cast( oot.Settable_Item(18) ),			type='num', name=bottle_names },
	{ pointer=oot.sav.inventory:rawget('bottle2'):cast( oot.Settable_Item(19) ),			type='num', name=bottle_names },
	{ pointer=oot.sav.inventory:rawget('bottle3'):cast( oot.Settable_Item(20) ),			type='num', name=bottle_names },
	{ pointer=oot.sav.inventory:rawget('bottle4'):cast( oot.Settable_Item(21) ),			type='num', name=bottle_names },
	{ pointer=oot.sav.inventory:rawget('adult_trade'):cast( oot.Settable_Item(22) ),		type='num', name=adult_trade_name },
	{ pointer=oot.sav.inventory:rawget('child_trade'):cast( oot.Settable_Item(23) ),		type='num', name=child_trade_name },

	{ pointer=oot.sav.ammo:rawget('deku_sticks'),	type='delta', receiveFunc=clamp( oot.sav.equipment:rawget('stick_capacity'):cast(oot.Implies_Max(oot.Bits(1,2), {
		[0] = 10,
		[1] = 10,
		[2] = 20,
		[2] = 30,
	})))},
	{ pointer=oot.sav.ammo:rawget('deku_nuts'),		type='delta', receiveFunc=clamp( oot.sav.equipment:rawget('nut_capacity'):cast(oot.Implies_Max(oot.Bits(4,5), {
		[0] = 20,
		[1] = 20,
		[2] = 30,
		[2] = 40,
	})))},
	{ pointer=oot.sav.ammo:rawget('bombs'),			type='delta', receiveFunc=clamp( oot.sav.equipment:rawget('bomb_bag'):cast(oot.Implies_Max(oot.Bits(3,4), {
		[0] = 0,
		[1] = 20,
		[2] = 30,
		[2] = 40,
	})))},
	{ pointer=oot.sav.ammo:rawget('bow'),			type='delta', receiveFunc=clamp( oot.sav.equipment:rawget('quiver'):cast(oot.Implies_Max(oot.Bits(0,1), {
		[0] = 0,
		[1] = 30,
		[2] = 40,
		[2] = 50,
	})))},
	{ pointer=oot.sav.ammo:rawget('slingshot'),		type='delta', receiveFunc=clamp( oot.sav.equipment:rawget('bullet_bag'):cast(oot.Implies_Max(oot.Bits(6,7), {
		[0] = 0,
		[1] = 30,
		[2] = 40,
		[2] = 50,
	})))},
	{ pointer=oot.sav.ammo:rawget('bombchus'),		type='delta', receiveFunc=const_clamp(50) },
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
	-- { pointer=oot.sav.quest_status:rawget('gerudo_card'),			type='bool' },
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

	{ pointer=oot.sav.small_keys:rawget('forest_temple'):cast( oot.Key ),			type='delta', name="Forest Temple Small Key", receiveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('fire_temple'):cast( oot.Key ),				type='delta', name="Fire Temple Small Key", receiveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('water_temple'):cast( oot.Key ),			type='delta', name="Water Temple Small Key", receiveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('spirit_temple'):cast( oot.Key ),			type='delta', name="Spirit Temple Small Key", receiveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('shadow_temple'):cast( oot.Key ),			type='delta', name="Shadow Temple Small Key", receiveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('bottom_of_the_well'):cast( oot.Key ),		type='delta', name="Bottom of the Well Small Key", receiveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('gerudo_training_ground'):cast( oot.Key ),	type='delta', name="Gerudo Training Ground Small Key", receiveFunc=monotonic },
	-- { pointer=oot.sav.small_keys:rawget('thieves_hideout'),		type='delta', name="Gerudo Fortress Small Key", receiveFunc=monotonic },
	{ pointer=oot.sav.small_keys:rawget('inside_ganons_castle'):cast( oot.Key ),	type='delta', name="Ganon's Castle Small Key", receiveFunc=monotonic },

	{ pointer=oot.sav.events[1]:rawget(4),			type='bool', name="[EVENT] Talon has fled the Castle" },
	{ pointer=oot.sav.events[3]:rawget(3),			type='bool', name="[EVENT] King Zora has Moved Aside" },
	{ pointer=oot.sav.events[4]:rawget(0),			type='bool', name="[EVENT] Obtained Zelda's Letter" },


	-- ['res']={ pointer=oot.state_fairy_queued:cast(oot.Fairy_Flag()), type='bool' },

}

-- add skulltula flags
for scene = 0x00, 0x17 do
	for b = 0, 7 do
		table.insert(ramItems, {
			pointer=oot.sav.skulltula_flags[scene]:rawget(b):cast( oot.Skulltula(oot.Bit(b), scene, bit.lshift(1, b)) ),
			type='token',
			name="Skulltula token +1"
		})
	end
end

-- Display a message of the ram event
local function getGUImessage(address, prevVal, newVal, user)
	-- Only display the message if there is a name for the address
	local name = ramItems[address].name
	if name and prevVal ~= newVal then
		-- If boolean, show 'Removed' for false
		if ramItems[address].type == "bool" then				
			gui.addmessage(user .. ": " .. name .. (newVal == false and 'Removed' or ''))
		-- If numeric, show the indexed name or name with value
		elseif ramItems[address].type == "num" then
			if (type(name) == 'string') then
				gui.addmessage(user .. ": " .. name .. " = " .. newVal)
			elseif (name[newVal]) then
				gui.addmessage(user .. ": " .. name[newVal])
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
		elseif ramItems[address].type == "tokencount" then
			gui.addmessage(user .. ": tokencount")
		elseif ramItems[address].type == "token" then
			gui.addmessage(user .. ": token" )
		else 
			gui.addmessage("Unknown item ram type")
		end
	end
end


-- Get the list of ram values
local function getRAM() 
	newRAM = {}
	for address, item in pairs(ramItems) do
		local ramval = item.pointer:rawget()
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
				ramevents[address] = (val ~= false)
				changes = true
			-- If numeric, get value
			elseif ramItems[address].type == "num" then
				ramevents[address] = val				
				changes = true
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
					ramevents[address] = newIndex - prevIndex
					changes = true
				end
			elseif ramItems[address].type == "tokencount" then
				-- supress token gets from the game
				oot.sav.gold_skulltulas = prevRAM[address]
				newRAM[address] = prevRAM[address]
				console.log('suppressed')
			elseif ramItems[address].type == "token" then
				ramevents[address] = (val ~= false)
				local tokens = oot.sav.gold_skulltulas + 1
				oot.sav.gold_skulltulas = tokens
				newRAM['skc'] = tokens
				prevRAM['skc'] = tokens
				changes = true
				console.log('tokened')
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

declare('ramItems', ramItems)
declare('getRAM', getRAM)
declare('eventRAMchanges', eventRAMchanges)


-- set a list of ram events
local function setRAMchanges(prevRAM, their_user, newEvents)
	for address, val in pairs(newEvents) do
		local newVal

		-- If boolean type value
		if ramItems[address].type == "bool" then
			newVal = val
		-- If numeric type value
		elseif ramItems[address].type == "num" then
			newVal = val
		-- If delta, add to the previous value
		elseif ramItems[address].type == "delta" then
			newVal = prevRAM[address] + val
		elseif ramItems[address].type == "deltalist" then
			local prevIndex = -1
			for k,v in pairs(ramItems[address].name) do
				if v.value == prevRAM[address] then
					prevIndex = k
				end
			end
			local newIndex = prevIndex + val
			if (prevIndex == -1 or ramItems[address].name[newIndex] == nil) then
				printOutput("Unknown ram list index value")
				newVal = prevRAM[address]
			else
				newVal = ramItems[address].name[newIndex].value
			end
		elseif ramItems[address].type == "tokencount" then
		elseif ramItems[address].type == "token" then
			newVal = val
			if prevRAM[address] ~= val then
				local tokens = oot.sav.gold_skulltulas + 1
				oot.sav.gold_skulltulas = tokens
				prevRAM['skc'] = tokens
			end
		else 
			printOutput("Unknown item ram type")
			newVal = prevRAM[address]
		end

		-- Run the address's reveive function if it exists
		if (ramItems[address].receiveFunc) then
			newVal = ramItems[address].receiveFunc(newVal, prevRAM[address], address, ramItems[address], their_user)
		end

		-- Write the new value
		getGUImessage(address, prevRAM[address], newVal, their_user)
		prevRAM[address] = newVal
		if oot.is_loaded_game_mode() then
			ramItems[address].pointer:set(newVal)
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
	-- Reload Core to restore previously removed items
	client.reboot_core()
	prevDomain = ""

	-- local junkItemsCount = tableCount(junkItems)
	-- math.randomseed(os.time())
	-- math.random(junkItemsCount)

	for ID, location in pairs(locations) do
		-- Remove item if it's not yours
		if (splitItems[ID] ~= my_ID) then
			-- Remove Item, Fill with junk
			-- memory.writebyte(location.address, junkItems[math.random(junkItemsCount)].val, "ROM")
			memory.writebyte(location.address, 0x4C, "ROM")
		end
	end
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
	local game_mode_details = {}
	gameMode, game_mode_details = oot.get_current_game_mode()
	local gameLoaded = game_mode_details.loaded
	local game_mode_name = game_mode_details.name

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
	-- if tableCount(deathQueue) > 0 and not deathQueue[config.user] then
	-- 	--kill link once it's safe (idk conditions for safe yet)
	-- 	if true then
	-- 		oot.sav.cur_health = 0
	-- 		prevRAM['chp'] = 0 --cur_health
	-- 	end
	-- end

	-- if game_mode_name == "Dying" then
	-- 	local deathCount = tableCount(deathQueue)
	-- 	console.log(deathQueue)
	-- 	if (deathCount > 0 and deathCount < playercount) then
	-- 		-- Lock the death until everyone is dying
	-- 		oot.freeze_death()
	-- 	elseif (deathCount >= playercount) then
	-- 		deathQueue = {}

	-- 		-- local hasFairy = ramItems['res'].pointer:get()

	-- 		local maxHP = oot.sav.max_health
	-- 		local contHP = 0x30
	-- 		-- if (hasFairy) then
	-- 		-- 	contHP = maxHP
	-- 		-- 	console.log('fairy')
	-- 		-- end
	-- 		prevRAM['chp'] = clamp( oot.sav:rawget('max_health') )(contHP) --cur_health
	-- 	end
	-- end

	-- -- Game was just loaded, restore to previous known RAM state
	if (gameLoaded and not oot.game_modes[prevGameMode].loaded) then
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
	-- if game_mode_name == "Dying" then
	-- 	if (oot.game_modes[prevGameMode].name ~= "Dying") then
	-- 		console.log('dead frame 1')
	-- 		if message == false then
	-- 			message = {}
	-- 		end

	-- 		message['chp'] = -0x400 -- death message is a large HP loss
	-- 		-- message['res'] = ramItems['res'].pointer:get()
	-- 		deathQueue[config.user] = true
	-- 	else 
	-- 		-- suppress all non death messages during death sequence
	-- 		return false
	-- 	end
	-- end
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

	if oot.is_loaded_game_mode() then
		prevRAM = setRAMchanges(prevRAM, their_user, message)
	else
		messageQueue.pushRight({["their_user"]=their_user, ["message"]=message})
	end
end

declare('getRAM', getRAM)

setmetatable(_G, old_global_metatable)

return oot_rom
