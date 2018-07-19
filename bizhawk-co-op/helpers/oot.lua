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
declare('oot', {})


-- some convinience functions

-- invert a table (assumes values are unique)
local function invert_table(t)
	local inverted = {}
	for key,val in pairs(t) do
		inverted[val] = key
	end
	return inverted
end

-- takes an int and returns hex string
local function hex(i)
	return string.format("0x%06x", i)
end

-- fight the power
local True = true
local False = false



-- a Layout describes how a section of memory is laid out
-- getting a specific data type should return its value,
-- getting a rescursive structure will return the structure with the layout (this is the default behavior)
local Layout = {
	rawget = function(pointer) return pointer.get(pointer) end,
	get = function(pointer) return pointer end,
	set = function(pointer, value) end
}
function Layout:create (l)
	setmetatable(l, self)
	self.__index = self
	return l
end

-- a Layout_Entry gives an offset within the Layout and, recursively, a Layout of memory at that offset
local function Layout_Entry(offset, layout)
	return { offset = offset, layout = layout }
end

-- convinient alias for Layout_Entry
local e = Layout_Entry


-- Pointer holds an absolute offset, and has a Layout as its type
local Pointer = {}
function Pointer:new (offset, layout)
	local p = { offset = offset, layout = layout }
	setmetatable(p, Pointer)
	return p
end
function Pointer:cast(layout)
	return Pointer:new(self.offset, layout)
end
function Pointer:rawget(key)
	if not self.layout[key] then
		return self.layout.rawget(self)
	end
	-- get the struct at this entry
	local inner = self.layout[key]
	-- update get the new offset and layout
	local offset = self.offset + inner.offset
	local layout = inner.layout
	-- create a new pointer
	return Pointer:new(offset, layout)
end
function Pointer:get() return self.layout.get(self) end
function Pointer:set(value) return self.layout.set(self, value) end
function Pointer.__index(pointer, key)
	if Pointer[key] then
		return Pointer[key]
	end
	-- get the pointer
	local p = pointer:rawget(key)
	-- resolve the pointer (if the layout is not concrete, it resolves to itself)
	return p:get()
end
function Pointer.__newindex(pointer, key, value)
	-- get the pointer
	local p = pointer:rawget(key)
	-- resolve the pointer (if the layout is not concrete, it resolves to itself)
	p:set(value)
end


-- CONCRETE TYPES

-- Int has a width in bytes to read
local function Int(width)
	local obj = Layout:create {}

	local gets = {
		[1] = function(p)return mainmemory.read_u8(p.offset) end,
		[2] = function(p) return mainmemory.read_u16_be(p.offset) end,
		[3] = function(p) return mainmemory.read_u24_be(p.offset) end,
		[4] = function(p) return mainmemory.read_u32_be(p.offset) end,
	}
	obj.get = gets[width]

	local sets = {
		[1] = function(p, value) mainmemory.write_u8(p.offset, value) end,
		[2] = function(p, value) mainmemory.write_u16_be(p.offset, value) end,
		[3] = function(p, value) mainmemory.write_u24_be(p.offset, value) end,
		[4] = function(p, value) mainmemory.write_u32_be(p.offset, value) end,
	}
	obj.set = sets[width]

	return obj
end

-- alias for types to save space by not creating them multiple times
local Int_8 = Int(1)
local Int_16 = Int(2)
local Int_24 = Int(3)
local Int_32 = Int(4)

-- Bit is a single flag at an address
-- values passed in and returned are booleans
local function Bit(pos)
	local obj = Layout:create {}

	function obj.get(p)
		return bit.check(mainmemory.read_u8(p.offset), pos)
	end

	function obj.set(p, value)
		local orig = mainmemory.readbyte(p.offset)
		local changed
		if value then
			changed = bit.set(orig, pos)
		else
			changed = bit.clear(orig, pos)
		end
		mainmemory.writebyte(p.offset, changed)
	end

	return obj
end

-- Bits is an int that is some mask of bits at the address
-- the range of bit positions is inclusive
local function Bits(start, ending)
	local obj = Layout:create {}

	local mask = 0x00
	for b = start, ending do
		mask = bit.set(mask, b)
	end

	function obj.get(p)
		return bit.rshift( bit.band(mainmemory.read_u8(p.offset), mask), start )
	end

	function obj.set(p, value)
		local orig = mainmemory.readbyte(p.offset)
		orig = bit.band( orig, bit.bnot(mask) )
		mainmemory.writebyte(p.offset, bit.bor(bit.lshift(value, start), orig) )
	end

	return obj
end

local function Value_Named_Layout(layout, lookup)
	local obj = Layout:create {}

	obj.lookup = lookup

	function obj.get(p)
		local value = layout.get(p)
		if lookup[value] then
	   		value = lookup[value]
		end
		return value
	end

	function obj.rawget(p)
		return layout.get(p)
	end

	local inverse_lookup = invert_table(lookup)

	function obj.set(p, value)
		if type(value) == "string" then
			if inverse_lookup[value] then
				value = inverse_lookup[value]
			else
				return
			end
		end
		layout.set(p, value)
	end

	return obj
end


-- RECURSIVE TYPES

-- holds a list of layouts of a given type, that can be indexed into
-- the Array can be given a list of names for each key to be used as an alternative lookup
local function Array(width, layout, keys)
	local obj = Layout:create {}

	obj.keys = keys

	setmetatable(obj, {
		__index = function(array, key)
			-- allows us to still call get and set
			if Layout[key] then
				return Layout[key]
			end
			-- compute the offset from the start of the array
			if type(key) == "string" then
				if keys[key] then
					key = keys[key]
				else
					key = 0
				end
			end
			local offset = key * width
			-- since this is a layout, we are expected to return a layout entry
			return e( offset, layout )
		end
	})

	return obj
end

-- holds a list of bit flags
-- the Bit_Array can be given a list of names for each key to be used as an alternative lookup
local function Bit_Array(bytes, keys)
	local obj = Layout:create {}

	obj.keys = keys

	setmetatable(obj, {
		__index = function(array, key)
			-- allows us to still call get and set
			if Layout[key] then
				return Layout[key]
			end
			-- compute the offset from the start of the array
			if type(key) == "string" then
				if keys[key] then
					key = keys[key]
				else
					key = 0
				end
			end
			local byte = bytes - math.floor(key / 8) - 1
			local bit = key % 8
			-- since this is a layout, we are expected to return a layout entry
			return e( byte, Bit(bit) )
		end
	})

	return obj
end

-- a pointer to a specific location in memory
local function Address(layout)
	local obj = Layout:create {}

	function obj.get(p)
		-- get the address
		local address = Int_32.get(p)
		address = bit.band(address, 0x00FFFFFF)
		-- return "Null" for address 0
		if address == 0 then
			return "Null"
		end
		-- create a pointer to it
		return Pointer:new( address, layout )
	end

	function obj.set(p, value)
		-- Null a pointer
		if value == "Null" then
			Int_32.set(p, 0)
			return
		end
		-- assume this is a Pointer
		if type(value) == "table" then
			value = value.offset
		end
		-- create address
		local address =  bit.bor(value, 0x80000000)
		Int_32.set(p, address)
	end

	return obj
end




-----------------------------------------------------------------------------------------
-- OOT STRUCTURES
-----------------------------------------------------------------------------------------

-- ToDo: expand this
local scene_names = {
	deku_tree = 0x00,
	dodongos_cavern = 0x01,
	jabu_jabus_belly = 0x02,
	forest_temple = 0x03,
	fire_temple = 0x04,
	water_temple = 0x05,
	spirit_temple = 0x06,
	shadow_temple = 0x07,
	bottom_of_the_well = 0x08,
	ice_cavern = 0x09,
	ganons_tower = 0x0A,
	gerudo_training_ground = 0x0B,
	thieves_hideout = 0x0C,
	inside_ganons_castle = 0x0D,
	treasure_box_shop = 0x10,
}

local actor_category = {
	switch = 0,
	prop1 = 1,
	player = 2,
	bomb = 3,
	npc = 4,
	enemy = 5,
	prop2 = 6,
	item = 7,
	misc = 8,
	boss = 9,
	door = 10,
	chest = 11,
}

local Actor = Layout:create {
	id =         e( 0x0000, Int_16 ),
	actor_type = e( 0x0002, Value_Named_Layout( Int_8, invert_table(actor_category) ) ),
	room =       e( 0x0003, Int_8 ),
	flags =      e( 0x0004, Bit_Array( 0x4 ) ),
	variable =   e( 0x001C, Int_16 ),

	-- there's a ton more stuff in here...

	health = e( 0x00AF, Int_8 ),
}
-- recursive atrribute must be outside initial definition...
Actor.prev_actor = e( 0x0120, Address(Actor) )
Actor.next_actor = e( 0x0124, Address(Actor) )

local Actor_Table_Entry = Layout:create {
	count = e( 0x00, Int_32 ),
	first = e( 0x04, Address(Actor) ),
}

local Global_Context = Layout:create {
	cur_scene =   e( 0x00A4, Value_Named_Layout(Int_16, invert_table(scene_names)) ),

	actor_table = e( 0x1C30, Array( 0x8, Actor_Table_Entry, actor_category ) ),

	switch_flags =      e( 0x1D28, Bit_Array( 0x4 ) ),
	temp_switch_flags = e( 0x1D2C, Bit_Array( 0x4 ) ),
	chest_flags =       e( 0x1D38, Bit_Array( 0x4 ) ),
	room_clear_flags =  e( 0x1D3C, Bit_Array( 0x4 ) ),
}



local item_slot_names = {	
	deku_sticks = 0x00,
	deku_nuts = 0x01,
	bombs = 0x02,
	bow = 0x03,
	fire_arrow = 0x04,
	dins_fire = 0x05,
	slingshot = 0x06,
	ocarina = 0x07,
	bombchus = 0x08,
	hookshot = 0x09,
	ice_arrow = 0x0A,
	farores_wind = 0x0B,
	boomerang = 0x0C,
	lens_of_truth = 0x0D,
	magic_beans = 0x0E,
	megaton_hammer = 0x0F,
	light_arrow = 0x10,
	nayrus_love = 0x11,
	bottle1 = 0x12,
	bottle2 = 0x13,
	bottle3 = 0x14,
	bottle4 = 0x15,
	adult_trade = 0x16,
	child_trade = 0x17,
}

local quest_status_names = {
	forest_medallion = 0,
	fire_medallion = 1,
	water_medallion = 2,
	spirit_medallion = 3,
	shadow_medallion = 4,
	light_medallion = 5,
	minuet_of_forest = 6,
	bolero_of_fire = 7,
	seranade_of_water = 8,
	requiem_of_spirit = 9,
	nocturne_of_shadow = 10,
	prelude_of_light = 11,
	zeldas_lullaby = 12,
	eponas_song = 13,
	sarias_song = 14,
	suns_song = 15,
	song_of_time = 16,
	song_of_storms = 17,
	kokiri_emerald = 18,
	goron_ruby = 19,
	zora_sapphire = 20,
	stone_of_agony = 21,
	gerudo_card = 22,
	skulltula_icon = 23,
}

local Item = Value_Named_Layout( Int_8, {
	[ 0xFF ] = "No Item",
	[ 0x00 ] = "Deku Sticks",
	[ 0x01 ] = "Deku Nuts",
	[ 0x02 ] = "Bombs",
	[ 0x03 ] = "Bow",
	[ 0x04 ] = "Fire Arrow",
	[ 0x05 ] = "Dins Fire",
	[ 0x06 ] = "Slingshot",
	[ 0x07 ] = "Fairy Ocarina",
	[ 0x08 ] = "Ocarina of Time",
	[ 0x09 ] = "Bombchus",
	[ 0x0A ] = "Hookshot",
	[ 0x0B ] = "Longshot",
	[ 0x0C ] = "Ice Arrow",
	[ 0x0D ] = "Farores Wind",
	[ 0x0E ] = "Boomerang",
	[ 0x0F ] = "Lens of Truth",
	[ 0x10 ] = "Magic Beans",
	[ 0x11 ] = "Megaton Hammer",
	[ 0x12 ] = "Light Arrow",
	[ 0x13 ] = "Nayrus Love",
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
	[ 0x2C ] = "Sold Out",
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
	--TODO: swords
})

local Equips = Layout:create {
	b_item =       e( 0x00, Item ),
	c_left_item =  e( 0x01, Item ),
	c_down_item =  e( 0x02, Item ),
	c_right_item = e( 0x03, Item ),
	c_left_slot =  e( 0x04, Int_8 ),
	c_down_slot =  e( 0x05, Int_8 ),
	c_right_slot = e( 0x06, Int_8 ),

	tunic =  e( 0x08, Bits(0,1) ),
	boots =  e( 0x08, Bits(4,5) ),
	sword =  e( 0x09, Bits(0,1) ),
	shield = e( 0x09, Bits(4,5) ),
}

local Equipment = Layout:create {
	kokiri_tunic =      e( 0x00, Bit(0) ),
	goron_tunic =       e( 0x00, Bit(1) ),
	zora_tunic =        e( 0x00, Bit(2) ),
	kokiri_boots =      e( 0x00, Bit(4) ),
	iron_boots =        e( 0x00, Bit(5) ),
	hover_boots =       e( 0x00, Bit(6) ),
	kokiri_sword =      e( 0x01, Bit(0) ),
	master_sword =      e( 0x01, Bit(1) ),
	biggoron_sword =    e( 0x01, Bit(2) ),
	broken_sword_icon = e( 0x01, Bit(3) ),
	kokiri_shield =     e( 0x01, Bit(4) ),
	hylian_shield =     e( 0x01, Bit(5) ),
	mirror_shield =     e( 0x01, Bit(6) ),

	stick_capacity = e( 0x05, Value_Named_Layout( Bits(1,2), {
		[0] = "No Sticks",
		[1] = "10 Sticks",
		[2] = "20 Sticks",
		[3] = "30 Sticks",
	} )),
	nut_capacity =   e( 0x05, Value_Named_Layout( Bits(4,5), {
		[0] = "No Nuts",
		[1] = "20 Nuts",
		[2] = "30 Nuts",
		[3] = "40 Nuts",
	} )),
	scale =          e( 0x06, Value_Named_Layout( Bits(1,2), {
		[0] = "No Scale",
		[1] = "Silver Scale",
		[2] = "Golden Scale",
	} )),
	wallet =         e( 0x06, Value_Named_Layout( Bits(4,5), {
		[0] = "Child's Wallet",
		[1] = "Adult's Wallet",
		[2] = "Giant's Wallet",
	} )),
	bullet_bag =     e( 0x06, Value_Named_Layout( Bits(6,7), {
		[0] = "No Bullet Bag",
		[1] = "Bullet Seed Bag",
		[2] = "Bigger Bullet Seed Bag",
		[3] = "Biggest Bullet Seed Bag",
	} )),
	quiver =         e( 0x07, Value_Named_Layout( Bits(0,1), {
		[0] = "No Quiver",
		[1] = "Quiver",
		[2] = "Bigger Quiver",
		[3] = "Biggest Quiver",
	} )),
	bomb_bag =       e( 0x07, Value_Named_Layout( Bits(3,4), {
		[0] = "No Bomb Bag",
		[1] = "Bomb Bag",
		[2] = "Bigger Bomb Bag",
		[3] = "Biggest Bomb Bag",
	} )),
	strength =       e( 0x07, Value_Named_Layout( Bits(6,7), {
		[0] = "No Strength Upgrade",
		[1] = "Goron Bracelet",
		[2] = "Silver Gauntlets",
		[3] = "Golden Gauntlets",
	} )),
}

local Dungeon_Item = Layout:create {
	boss_key = e( 0x0, Bit(0) ),
	compass =  e( 0x0, Bit(1) ),
	map =      e( 0x0, Bit(2) ),
}

local Scene_Flags_Type = Layout:create {
	chest_flags =       e( 0x00, Bit_Array( 0x4 ) ),
	switch_flags =      e( 0x04, Bit_Array( 0x4 ) ),
	room_clear_flags =  e( 0x08, Bit_Array( 0x4 ) ),
	collectible_flags = e( 0x0C, Bit_Array( 0x4 ) ),
	visited_rooms =     e( 0x14, Bit_Array( 0x4 ) ),
	visited_floors =    e( 0x18, Bit_Array( 0x4 ) ),
}

local Save_Context = Layout:create {
	time = 					 e( 0x000C, Int_16 ),
	max_health =             e( 0x002E, Int_16 ),
	cur_health =             e( 0x0030, Int_16 ),
	magic_meter_level =      e( 0x0032, Int_8 ),
	cur_magic =              e( 0x0033, Int_8 ),
	rupees =                 e( 0x0034, Int_16 ),
	have_magic =             e( 0x003A, Bit(0) ),
	have_double_magic =      e( 0x003C, Bit(0) ),
	double_defense =         e( 0x003D, Bit(0) ),
	biggoron_sword_durable = e( 0x003E, Bit(0) ),

	stored_child_equips = e( 0x0040, Equips ),
	stored_adult_equips = e( 0x004A, Equips ),
	current_equips =      e( 0x0068, Equips ),

	inventory = e( 0x0074, Array( 1, Item, item_slot_names ) ),
	ammo =      e( 0x008C, Array( 1, Int_8, item_slot_names ) ),

	beans_purchased = e( 0x009B, Int_8 ),

	equipment =    e( 0x009C, Equipment ),
	heart_pieces = e( 0x00A4, Bits(4,5) ),
	quest_status = e( 0x00A5, Bit_Array( 0x3, quest_status_names ) ),

	dungeon_items = e( 0x00A8, Array( 0x1, Dungeon_Item, scene_names ) ),
	small_keys =    e( 0x00BC, Array( 0x1, Int_8, scene_names ) ),

	double_defense_hearts = e( 0x00CF, Int_8 ),
	gold_skulltulas =       e( 0x00D0, Int_16 ),

	scene_flags = e( 0x00D4, Array( 0x1C, Scene_Flags_Type, scene_names ) ),

	skulltula_flags = e( 0xE9C, Array( 0x1, Bit_Array( 0x1 ) ) ),

	events = e( 0xED4, Array( 0x2, Bit_Array( 0x2 ) ) ),

	magic_meter_size = e( 0x13F4, Int_16 ),

}

-- events:
-- [1][4] Talon has fled castle
-- [3][3] King Zora Moved
-- [4][0] Obtained Zelda's Letter


local save_context = Pointer:new( 0x11A5D0, Save_Context )
local global_context = Pointer:new( 0x1C84A0, Global_Context )

-- declare('find_malon', function() 
-- 	local npc = global_context.actor_table.npc.first
-- 	while npc ~= "Null" do
-- 		if npc.id == 0xE7 then return npc end
-- 		npc = npc.next_actor
-- 	end
-- 	return "Null"
-- end)




-- finds an actor in a given linked list of actor by id
-- if filter is given, only take one for which filter returns true
-- returns the first valid actor in the list, or "Null" (a string) if none are found
local function find_actor(table_entry, id, filter)
	local actor = table_entry.first
	while actor ~= "Null" do
		if actor.id == id then
			if filter then
				if filter(actor) then
					return actor
				end
			else
				return actor
			end
		end
		actor = actor.next_actor
	end
	return "Null"
end

-- remove a given actor from the given list
-- I guess this leaks memory? hopefully oot doesn't mind lol
local function remove_actor(table_entry, actor)
	-- remove the pointer to this actor from the next actor in the list
	local next_actor = actor.next_actor
	if next_actor ~= "Null" then
		next_actor.prev_actor = actor.prev_actor
	end
	-- remove the pointer to this actor from the previous actor (or the table entry)
	local prev_actor = actor.prev_actor
	if prev_actor ~= "Null" then
		prev_actor.next_actor = actor.next_actor
	else
		table_entry.first = actor.next_actor
	end
	-- reduce the count in the actor table
	table_entry.count = table_entry.count - 1
end



-- skulltula location variables (variable & 0x1F00) -> array index in save context
-- 0x00: deku tree     -> 0x03
-- 0x01: dodongo       -> 0x02
-- 0x02: jabu          -> 0x01
-- 0x03: forest temple -> 0x00
-- 0x04: fire temple   -> 0x07
-- 0x0C: kokiri forest -> 0x0F
-- 0x0D: lost woods    -> 0x0E
-- 0x0E: market/castle -> 0x0D
-- 0x0F: death mountain-> 0x0C
-- 0x10: kak           -> 0x13
-- 0x11: zora river    -> 0x12
-- this implies a nice pattern...

-- this function is an involution
local function skulltula_scene_to_array_index(i)
	return  (i + 3) - 2 * (i % 4)
end

local function find_gold_skulltula(scene, flag)
	local filter = function(actor)
		local actor_scene = bit.rshift(bit.band(actor.variable, 0x1F00), 8)
		local actor_flag = bit.band(actor.variable, 0xFF)
		return scene == actor_scene and flag == actor_flag
	end

	return find_actor(global_context.actor_table.npc, 0x95, filter)
end

local function find_skulltula_token(scene, flag)
	local filter = function(actor)
		local actor_scene = bit.rshift(bit.band(actor.variable, 0x1F00), 8)
		local actor_flag = bit.band(actor.variable, 0xFF)
		return scene == actor_scene and flag == actor_flag
	end

	return find_actor(global_context.actor_table.item, 0x19C, filter)
end

local function remove_skulltula(scene, flag)
	-- remove any enemy with this scene/flag
	local skulltula = find_gold_skulltula(scene, flag)
	if skulltula ~= "Null" then
		remove_actor(global_context.actor_table.npc, skulltula)
	end
	-- remove any token with this scene/flag
	local token = find_skulltula_token(scene, flag)
	if token ~= "Null" then
		remove_actor(global_context.actor_table.item, token)
	end
end






-- SPECIAL TYPES

-- A Key treats -1 keys (never found any) as 0
local Key = Int(1)
local old_key_get = Key.get
Key.get = function(p)
	local val = old_key_get(p)
	if val == 0xFF then
		return 0
	end
	return val
end

-- setting an equipment item to false will unequip it
local function Settable_Equipment(layout, equipment_name, default)

	local obj = Layout:create {}

	function obj.get(p)
		return layout.get(p)
	end

	function obj.set(p, value)
		layout.set(p, value)
		if value == false then
			save_context.current_equips[equipment_name] = default
			-- TODO remove equipment's usability on the spot
		end
	end

	return obj

end

-- setting an item with a Settable_Item will update c buttons as well
local function Settable_Item(item_num)
	local obj = Int(1)

	local old_item_set = obj.set

	obj.set = function(p, val)
		old_item_set(p, val)
		local buttons = { c_left_item='c_left_slot', c_down_item='c_down_slot', c_right_item='c_right_slot'}
		for item, slot in pairs(buttons) do
			if save_context.current_equips[slot] == item_num then
				save_context.current_equips[item] = val
				-- TODO: update the icon
			end
		end
	end

	return obj
end

-- magic has a number of values that need to update together
local Magic_Meter = Int(1)
local old_magic_set = Magic_Meter.set
Magic_Meter.set = function(p, val)
	old_magic_set(p, val)
	if val == 0 then
		save_context.have_magic = false
		save_context.have_double_magic = false
		save_context.magic_meter_size = 0
	elseif val == 1 then
		save_context.have_magic = true
		save_context.have_double_magic = false
		save_context.magic_meter_size = 0x30
	elseif val == 2 then
		save_context.have_magic = true
		save_context.have_double_magic = true
		save_context.magic_meter_size = 0x60
	end
end

-- when a value of this type is looked up, return the capacity implied by that value
local function Implies_Max(layout, maxes)

	local obj = Layout:create {}

	obj.maxes = maxes

	function obj.get(p)
		value = layout.get(p)
		if maxes[value] then
	   		value = maxes[value]
		end
		return value
	end

	function obj.set(p, value)
		layout.set(p, value)
	end

	return obj
end

-- sending fairy messages will only have an effect when dead
local function Fairy_Flag()
	local obj = Bit(0)

	local old_item_get = obj.get

	obj.get = function(p)
		if save_context.cur_health > 0 then
			return 0
		end
		return old_item_get(p)
	end

	local old_item_set = obj.set

	obj.set = function(p, val)
		if save_context.cur_health <= 0 then
			if val then
				old_item_set(p, val)
			end
		end
	end

	return obj
end

-- a Skulltula pointer knows to delete a skulltula actor on the spot if it's around
local function Skulltula(layout, scene, flag)
	local obj = Layout:create {}

	function obj.get(p)
		return layout.get(p)
	end

	function obj.set(p, value)
		layout.set(p, value)
		-- delete skulltula that's already collected
		if value then
			remove_skulltula(skulltula_scene_to_array_index(scene), flag)
		end
	end

	return obj
end





-- GAME STATE
local state_main = Pointer:new( 0x11B92F, Int(1) )
local state_sub = Pointer:new( 0x11B933, Int(1) )
local state_menu = Pointer:new( 0x1D8DD5, Int(1) )
local state_logo = Pointer:new( 0x11F200, Int(4) )
local state_link = Pointer:new( 0x1DB09C, Bit_Array( 0x8, {dying=0x27} ) )
local state_fairy_queued = Pointer:new( 0x1DB26F, Bit(0) )


local game_modes = {
	[-1]={name="Unknown", loaded=false},
	[0]={name="N64 Logo", loaded=false},
	[1]={name="Title Screen", loaded=false},
	[2]={name="File Select", loaded=false},
	[3]={name="Normal Gameplay", loaded=true},
	[4]={name="Cutscene", loaded=true},
	[5]={name="Paused", loaded=true},
	[6]={name="Dying", loaded=true},
	[7]={name="Dying Menu Start", loaded=false},
	[8]={name="Dead", loaded=false},
}

local function get_current_game_mode()
	local mode = -1
	local logo_state = state_logo:get()
	if logo_state == 0x802C5880 or logo_state == 0x00000000 then
		mode = 0
	else
		if state_main:get() == 1 then
			mode = 1
		elseif state_main:get() == 2 then
			mode = 2
		else
			local menu_state = state_menu:get()
			if menu_state == 0 then
				if state_link.dying or save_context.cur_health <= 0 then
					mode = 6
				else
					if state_sub:get() == 4 then
						mode = 4
					else
						mode = 3
					end
				end
			elseif (0 < menu_state and menu_state < 9) or menu_state == 13 then
				mode = 5
			elseif menu_state == 9 or menu_state == 0xB then
				mode = 7
			else
				mode = 8
			end
		end
	end
	return mode, game_modes[mode]
end

local function is_loaded_game_mode()
	return game_modes[get_current_game_mode()].loaded
end

local function freeze_death()
	state_link.dying = false
end

-- public facing members
oot.sav = save_context
oot.ctx = global_context
oot.find_actor = find_actor
oot.Bit = Bit
oot.Bits = Bits
oot.Key = Key
oot.Settable_Item = Settable_Item
oot.Settable_Equipment = Settable_Equipment
oot.Implies_Max = Implies_Max
oot.Magic_Meter = Magic_Meter
oot.Fairy_Flag = Fairy_Flag
oot.Skulltula = Skulltula
oot.game_modes = game_modes
oot.get_current_game_mode = get_current_game_mode
oot.is_loaded_game_mode = is_loaded_game_mode
oot.freeze_death = freeze_death
oot.state_fairy_queued = state_fairy_queued

-- give the good stuff
oot.deck_me_out = function()
	oot.sav.max_health = 0x140
	oot.sav.cur_health = 0x140
	oot.sav.magic_meter_level = 0x2
	oot.sav.cur_magic = 0x60
	oot.sav.magic_meter_size = 0x60
	oot.sav.have_magic = true
	oot.sav.have_double_magic = true
	oot.sav.biggoron_sword_durable = true
	oot.sav.double_defense = true
	oot.sav.rupees = 500
	oot.sav.double_defense_hearts = 0x140
	oot.sav.beans_purchased = 0

	oot.sav.magic_meter_level = 0x2
	oot.sav.magic_meter_level = 0x2
	oot.sav.magic_meter_level = 0x2
	oot.sav.magic_meter_level = 0x2
	oot.sav.magic_meter_level = 0x2
	oot.sav.magic_meter_level = 0x2
	oot.sav.magic_meter_level = 0x2
	oot.sav.magic_meter_level = 0x2
	oot.sav.magic_meter_level = 0x2
	oot.sav.magic_meter_level = 0x2
	oot.sav.magic_meter_level = 0x2

	for dungeon = 0x00, 0x0D do
		oot.sav.dungeon_items[dungeon].map = true
		oot.sav.dungeon_items[dungeon].compass = true
		oot.sav.dungeon_items[dungeon].boss_key = true
		oot.sav.small_keys[dungeon] = 9
	end

	oot.sav.inventory.deku_sticks = "Deku Sticks"
	oot.sav.inventory.deku_nuts = "Deku Nuts"
	oot.sav.inventory.bombs = "Bombs"
	oot.sav.inventory.bow = "Bow"
	oot.sav.inventory.fire_arrow = "Fire Arrow"
	oot.sav.inventory.dins_fire = "Dins Fire"
	oot.sav.inventory.slingshot = "Slingshot"
	oot.sav.inventory.ocarina = "Ocarina of Time"
	oot.sav.inventory.bombchus = "Bombchus"
	oot.sav.inventory.hookshot = "Longshot"
	oot.sav.inventory.ice_arrow = "Ice Arrow"
	oot.sav.inventory.farores_wind = "Farores Wind"
	oot.sav.inventory.boomerang = "Boomerang"
	oot.sav.inventory.lens_of_truth = "Lens of Truth"
	oot.sav.inventory.magic_beans = "Magic Beans"
	oot.sav.inventory.megaton_hammer = "Megaton Hammer"
	oot.sav.inventory.light_arrow = "Light Arrow"
	oot.sav.inventory.nayrus_love = "Nayrus Love"
	oot.sav.inventory.bottle1 = "Bug"
	oot.sav.inventory.bottle2 = "Fish"
	oot.sav.inventory.bottle3 = "Blue Fire"
	oot.sav.inventory.bottle4 = "Rutos Letter"
	oot.sav.inventory.adult_trade = "Sold Out"
	oot.sav.inventory.child_trade = "Chicken"

	oot.sav.ammo.deku_sticks = 30
	oot.sav.ammo.deku_nuts = 40
	oot.sav.ammo.bombs = 40
	oot.sav.ammo.bow = 50
	oot.sav.ammo.slingshot = 50
	oot.sav.ammo.bombchus = 50
	oot.sav.ammo.magic_beans = 10

	oot.sav.equipment.kokiri_tunic = true
	oot.sav.equipment.goron_tunic = true
	oot.sav.equipment.zora_tunic = true
	oot.sav.equipment.kokiri_boots = true
	oot.sav.equipment.iron_boots = true
	oot.sav.equipment.hover_boots = true
	oot.sav.equipment.kokiri_sword = true
	oot.sav.equipment.master_sword = true
	oot.sav.equipment.biggoron_sword = true
	oot.sav.equipment.broken_sword_icon = true
	oot.sav.equipment.kokiri_shield = true
	oot.sav.equipment.hylian_shield = true
	oot.sav.equipment.mirror_shield = true

	oot.sav.equipment.stick_capacity = "30 Sticks"
	oot.sav.equipment.nut_capacity = "40 Nuts"
	oot.sav.equipment.scale = "Golden Scale"
	oot.sav.equipment.wallet = "Giant's Wallet"
	oot.sav.equipment.bullet_bag = "Biggest Bullet Seed Bag"
	oot.sav.equipment.quiver = "Biggest Quiver"
	oot.sav.equipment.bomb_bag = "Biggest Bomb Bag"
	oot.sav.equipment.strength = "Golden Gauntlets"

	oot.sav.quest_status.minuet_of_forest = true
	oot.sav.quest_status.bolero_of_fire = true
	oot.sav.quest_status.seranade_of_water = true
	oot.sav.quest_status.requiem_of_spirit = true
	oot.sav.quest_status.nocturne_of_shadow = true
	oot.sav.quest_status.prelude_of_light = true
	oot.sav.quest_status.zeldas_lullaby = true
	oot.sav.quest_status.eponas_song = true
	oot.sav.quest_status.sarias_song = true
	oot.sav.quest_status.suns_song = true
	oot.sav.quest_status.song_of_time = true
	oot.sav.quest_status.song_of_storms = true

end

-- oot.should_freeze = true

-- local dying = false
-- 	client.SetGameExtraPadding(0, 16, 0, 0)
-- 	local mode = 0
-- 	local details = {}
-- 	while 1 do
-- 		mode, details = get_current_game_mode()
-- 		if mode == -1 then
-- 			error("unknown state:\n" ..
-- 				  "main: " .. state_main:get() .. "\n" ..
-- 				  "sub:  " .. state_sub:get() .. "\n" ..
-- 				  "menu: " .. state_menu:get() .. "\n" ..
-- 				  "logo: " .. hex(state_logo:get()) .. "\n")
-- 		end
-- 		if mode == 6 then
-- 			dying = true
-- 		end
-- 		if dying then
-- 			if oot.should_freeze then
-- 				freeze_death()
-- 			else
-- 				dying = false
-- 			end
-- 		end
-- 		gui.drawString(0, 0, details.name)
-- 		emu.yield()
-- 		emu.yield()
-- 	end


setmetatable(_G, old_global_metatable)

return oot