local items = {
	[0x5A] = 'Nothing',
	[0x49] = 'Fighters Sword',
	[0x00] = 'Fighters Sword and Shield',
	[0x01] = 'Master Sword',
	[0x50] = 'Master Sword',
	[0x02] = 'Tempered Sword',
	[0x03] = 'Golden Sword',
	[0x04] = 'Fighters Shield',
	[0x05] = 'Fire Shield',
	[0x06] = 'Mirror Shield',
	[0x07] = 'Fire Rod',
	[0x08] = 'Ice Rod',
	[0x09] = 'Hammer',
	[0x0A] = 'Hookshot',
	[0x0B] = 'Bow',
	[0x0C] = 'Boomerang',
	[0x0D] = 'Magic Powder',
	[0x0E] = 'Bee',
	[0x0F] = 'Bombos',
	[0x10] = 'Ether',
	[0x11] = 'Quake',
	[0x12] = 'Lamp',
	[0x13] = 'Shovel',
	[0x14] = 'Flute',
	[0x15] = 'Cane Of Somaria',
	[0x16] = 'Bottle (Empty)',
	[0x17] = 'Piece Of Heart',
	[0x18] = 'Cane Of Byrna',
	[0x19] = 'Magic Cape',
	[0x1A] = 'Magic Mirror',
	[0x1B] = 'Power Glove',
	[0x1C] = 'Titans Mitt',
	[0x1D] = 'Book Of Mudora',
	[0x1E] = 'Flippers',
	[0x1F] = 'Moon Pearl',
	[0x21] = 'Bug Catching Net',
	[0x22] = 'Blue Mail',
	[0x23] = 'Red Mail',
--	[0x24] = 'Key',
	[0x25] = 'Compass',
	[0x26] = 'Heart Container (no animation)',
	[0x27] = 'Bomb',
	[0x28] = 'Three Bombs',
	[0x29] = 'Mushroom',
	[0x2A] = 'Magical Boomerang',
	[0x2B] = 'Bottle (Red Potion)',
	[0x2C] = 'Bottle (Green Potion)',
	[0x2D] = 'Bottle (Blue Potion)',
	[0x2E] = 'Red Potion',
	[0x2F] = 'Green Potion',
	[0x30] = 'Blue Potion',
	[0x31] = 'Ten Bombs',
	[0x32] = 'Big Key',
	[0x33] = 'Dungeon Map',
	[0x34] = 'One Rupee',
	[0x35] = 'Five Rupees',
	[0x36] = 'Twenty Rupees',
	[0x3A] = 'Bow And Arrows',
	[0x3B] = 'Bow And Silver Arrows',
	[0x3C] = 'Bottle (Bee)',
	[0x3D] = 'Bottle (Fairy)',
	[0x3E] = 'Heart Container',
	[0x3F] = 'Heart Container (refill)',
	[0x40] = 'One Hundred Rupees',
	[0x41] = 'Fifty Rupees',
	[0x42] = 'Heart',
	[0x43] = 'Arrow',
	[0x44] = 'Ten Arrows',
	[0x45] = 'Small Magic',
	[0x46] = 'Three Hundred Rupees',
	[0x47] = 'Twenty Rupees',
	[0x48] = 'Bottle (Golden Bee)',
	[0x4A] = 'Flute (active)',
	[0x4B] = 'Pegasus Boots',
	[0x51] = 'Bomb Upgrade (5)',
	[0x52] = 'Bomb Upgrade (10)',
	[0x4C] = 'Bomb Upgrade (50)',
	[0x53] = 'Arrow Upgrade (5)',
	[0x54] = 'Arrow Upgrade (10)',
	[0x4D] = 'Arrow Upgrade (70)',
	[0x4E] = 'Half Magic',
	[0x4F] = 'Quarter Magic',
	[0x55] = 'Programmable 1',
	[0x56] = 'Programmable 2',
	[0x57] = 'Programmable 3',
	[0x58] = 'Silver Arrows Upgrade',
	[0x59] = 'Rupoor',
	[0x5B] = 'Red Clock',
	[0x5C] = 'Blue Clock',
	[0x5D] = 'Green Clock',
	[0x5E] = 'Progressive Sword',
	[0x5F] = 'Progressive Shield',
	[0x60] = 'Progressive Armor',
	[0x61] = 'Progressive Glove',
	[0x62] = 'Unique RNG Item',
	[0x63] = 'Non-Unique RNG Item',
	[0x6A] = 'Triforce',
	[0x6B] = 'Power Star',
	[0x6C] = 'Triforce Piece',
	[0x70] = 'Light World Map',
	[0x71] = 'Dark World Map',
	[0x72] = 'Ganons Tower Map',
	[0x73] = 'Turtle Rock Map',
	[0x74] = 'Thieves Town Map',
	[0x75] = 'Tower of Hera Map',
	[0x76] = 'Ice Palace Map',
	[0x77] = 'Skull Woods Map',
	[0x78] = 'Misery Mire Map',
	[0x79] = 'Palace of Darkness Map',
	[0x7A] = 'Swamp Palace Map',
	[0x7B] = 'Agahnims Tower Map',
	[0x7C] = 'Desert Palace Map',
	[0x7D] = 'Eastern Palace Map',
	[0x7E] = 'Hyrule Castle Map',
	[0x7F] = 'Sewers Map',
	[0x82] = 'Ganons Tower Compass',
	[0x83] = 'Turtle Rock Compass',
	[0x84] = 'Thieves Town Compass',
	[0x85] = 'Tower of Hera Compass',
	[0x86] = 'Ice Palace Compass',
	[0x87] = 'Skull Woods Compass',
	[0x88] = 'Misery Mire Compass',
	[0x89] = 'Palace of Darkness Compass',
	[0x8A] = 'Swamp Palace Compass',
	[0x8B] = 'Agahnims Tower Compass',
	[0x8C] = 'Desert Palace Compass',
	[0x8D] = 'Eastern Palace Compass',
	[0x8E] = 'Hyrule Castle Compass',
	[0x8F] = 'Sewers Compass',
	[0x92] = 'Ganons Tower Big Key',
	[0x93] = 'Turtle Rock Big Key',
	[0x94] = 'Thieves Town Big Key',
	[0x95] = 'Tower of Hera Big Key',
	[0x96] = 'Ice Palace Big Key',
	[0x97] = 'Skull Woods Big Key',
	[0x98] = 'Misery Mire Big Key',
	[0x99] = 'Palace of Darkness Big Key',
	[0x9A] = 'Swamp Palace Big Key',
	[0x9B] = 'Agahnims Tower Big Key',
	[0x9C] = 'Desert Palace Big Key',
	[0x9D] = 'Eastern Palace Big Key',
	[0x9E] = 'Hyrule Castle Big Key',
	[0x9F] = 'Sewers Big Key',
--	[0xA0] = 'Sewers Key',
--	[0xA1] = 'Hyrule Castle Key',
--	[0xA2] = 'Eastern Palace Key',
--	[0xA3] = 'Desert Palace Key',
--	[0xA4] = 'Agahnims Tower Key',
--	[0xA5] = 'Swamp Palace Key',
--	[0xA6] = 'Palace of Darkness Key',
--	[0xA7] = 'Misery Mire Key',
--	[0xA8] = 'Skull Woods Key',
--	[0xA9] = 'Ice Palace Key',
--	[0xAA] = 'Tower of Hera Key',
--	[0xAB] = 'Thieves Town Key',
--	[0xAC] = 'Turtle Rock Key',
--	[0xAD] = 'Ganons Tower Key',
}

local locations = {
	[0] = {["address"]=0xEA16, ["name"]="Turtle Rock - Chain Chomps",	["type"]="Chest"},
	{["address"]=0xEA22, ["name"]="Turtle Rock - Compass Chest",	["type"]="Chest"},
	{["address"]=0xEA1C, ["name"]="Turtle Rock - Roller Room - Left",	["type"]="Chest"},
	{["address"]=0xEA1F, ["name"]="Turtle Rock - Roller Room - Right",	["type"]="Chest"},
	{["address"]=0xEA19, ["name"]="Turtle Rock - Big Chest",	["type"]="BigChest"},
	{["address"]=0xEA25, ["name"]="Turtle Rock - Big Key Chest",	["type"]="Chest"},
	{["address"]=0xEA34, ["name"]="Turtle Rock - Crystaroller Room",	["type"]="Chest"},
	{["address"]=0xEA31, ["name"]="Turtle Rock - Eye Bridge - Bottom Left",	["type"]="Chest"},
	{["address"]=0xEA2E, ["name"]="Turtle Rock - Eye Bridge - Bottom Right",	["type"]="Chest"},
	{["address"]=0xEA2B, ["name"]="Turtle Rock - Eye Bridge - Top Left",	["type"]="Chest"},
	{["address"]=0xEA28, ["name"]="Turtle Rock - Eye Bridge - Top Right",	["type"]="Chest"},
	{["address"]=0x180159, ["name"]="Turtle Rock - Trinexx",	["type"]="Drop"},
	{["address"]=0xE9E6, ["name"]="Tower of Hera - Big Key Chest",	["type"]="Chest"},
	{["address"]=0x180162, ["name"]="Tower of Hera - Basement Cage",	["type"]="Standing\HeraBasement"},
	{["address"]=0xE9AD, ["name"]="Tower of Hera - Map Chest",	["type"]="Chest"},
	{["address"]=0xE9FB, ["name"]="Tower of Hera - Compass Chest",	["type"]="Chest"},
	{["address"]=0xE9F8, ["name"]="Tower of Hera - Big Chest",	["type"]="BigChest"},
	{["address"]=0x180152, ["name"]="Tower of Hera - Moldorm",	["type"]="Drop"},
	{["address"]=0xEA0D, ["name"]="Thieves' Town - Attic",	["type"]="Chest"},
	{["address"]=0xEA04, ["name"]="Thieves' Town - Big Key Chest",	["type"]="Chest"},
	{["address"]=0xEA01, ["name"]="Thieves' Town - Map Chest",	["type"]="Chest"},
	{["address"]=0xEA07, ["name"]="Thieves' Town - Compass Chest",	["type"]="Chest"},
	{["address"]=0xEA0A, ["name"]="Thieves' Town - Ambush Chest",	["type"]="Chest"},
	{["address"]=0xEA10, ["name"]="Thieves' Town - Big Chest",	["type"]="BigChest"},
	{["address"]=0xEA13, ["name"]="Thieves' Town - Blind's Cell",	["type"]="Chest"},
	{["address"]=0x180156, ["name"]="Thieves' Town - Blind",	["type"]="Drop"},
	{["address"]=0xEA9D, ["name"]="Swamp Palace - Entrance",	["type"]="Chest"},
	{["address"]=0xE989, ["name"]="Swamp Palace - Big Chest",	["type"]="BigChest"},
	{["address"]=0xEAA6, ["name"]="Swamp Palace - Big Key Chest",	["type"]="Chest"},
	{["address"]=0xE986, ["name"]="Swamp Palace - Map Chest",	["type"]="Chest"},
	{["address"]=0xEAA3, ["name"]="Swamp Palace - West Chest",	["type"]="Chest"},
	{["address"]=0xEAA0, ["name"]="Swamp Palace - Compass Chest",	["type"]="Chest"},
	{["address"]=0xEAA9, ["name"]="Swamp Palace - Flooded Room - Left",	["type"]="Chest"},
	{["address"]=0xEAAC, ["name"]="Swamp Palace - Flooded Room - Right",	["type"]="Chest"},
	{["address"]=0xEAAF, ["name"]="Swamp Palace - Waterfall Room",	["type"]="Chest"},
	{["address"]=0x180154, ["name"]="Swamp Palace - Arrghus",	["type"]="Drop"},
	{["address"]=0xE998, ["name"]="Skull Woods - Big Chest",	["type"]="BigChest"},
	{["address"]=0xE99E, ["name"]="Skull Woods - Big Key Chest",	["type"]="Chest"},
	{["address"]=0xE992, ["name"]="Skull Woods - Compass Chest",	["type"]="Chest"},
	{["address"]=0xE99B, ["name"]="Skull Woods - Map Chest",	["type"]="Chest"},
	{["address"]=0xE9FE, ["name"]="Skull Woods - Bridge Room",	["type"]="Chest"},
	{["address"]=0xE9A1, ["name"]="Skull Woods - Pot Prison",	["type"]="Chest"},
	{["address"]=0xE9C8, ["name"]="Skull Woods - Pinball Room",	["type"]="Chest"},
	{["address"]=0x180155, ["name"]="Skull Woods - Mothula",	["type"]="Drop"},
	{["address"]=0xEA5B, ["name"]="Palace of Darkness - Shooter Room",	["type"]="Chest"},
	{["address"]=0xEA37, ["name"]="Palace of Darkness - Big Key Chest",	["type"]="Chest"},
	{["address"]=0xEA3A, ["name"]="Palace of Darkness - The Arena - Ledge",	["type"]="Chest"},
	{["address"]=0xEA3D, ["name"]="Palace of Darkness - The Arena - Bridge",	["type"]="Chest"},
	{["address"]=0xEA49, ["name"]="Palace of Darkness - Stalfos Basement",	["type"]="Chest"},
	{["address"]=0xEA52, ["name"]="Palace of Darkness - Map Chest",	["type"]="Chest"},
	{["address"]=0xEA40, ["name"]="Palace of Darkness - Big Chest",	["type"]="BigChest"},
	{["address"]=0xEA43, ["name"]="Palace of Darkness - Compass Chest",	["type"]="Chest"},
	{["address"]=0xEA46, ["name"]="Palace of Darkness - Harmless Hellway",	["type"]="Chest"},
	{["address"]=0xEA4C, ["name"]="Palace of Darkness - Dark Basement - Left",	["type"]="Chest"},
	{["address"]=0xEA4F, ["name"]="Palace of Darkness - Dark Basement - Right",	["type"]="Chest"},
	{["address"]=0xEA55, ["name"]="Palace of Darkness - Dark Maze - Top",	["type"]="Chest"},
	{["address"]=0xEA58, ["name"]="Palace of Darkness - Dark Maze - Bottom",	["type"]="Chest"},
	{["address"]=0x180153, ["name"]="Palace of Darkness - Helmasaur King",	["type"]="Drop"},
	{["address"]=0xEA67, ["name"]="Misery Mire - Big Chest",	["type"]="BigChest"},
	{["address"]=0xEA5E, ["name"]="Misery Mire - Main Lobby",	["type"]="Chest"},
	{["address"]=0xEA6D, ["name"]="Misery Mire - Big Key Chest",	["type"]="Chest"},
	{["address"]=0xEA64, ["name"]="Misery Mire - Compass Chest",	["type"]="Chest"},
	{["address"]=0xEA61, ["name"]="Misery Mire - Bridge Chest",	["type"]="Chest"},
	{["address"]=0xEA6A, ["name"]="Misery Mire - Map Chest",	["type"]="Chest"},
	{["address"]=0xE9DA, ["name"]="Misery Mire - Spike Chest",	["type"]="Chest"},
	{["address"]=0x180158, ["name"]="Misery Mire - Vitreous",	["type"]="Drop"},
	{["address"]=0x289B0, ["name"]="Master Sword Pedestal",	["type"]="Pedestal"},
	{["address"]=0x2DF45, ["name"]="Link's Uncle",	["type"]="Npc"},
	{["address"]=0xE971, ["name"]="Secret Passage",	["type"]="Chest"},
	{["address"]=0xE97A, ["name"]="King's Tomb",	["type"]="Chest"},
	{["address"]=0xE98C, ["name"]="Floodgate Chest",	["type"]="Chest"},
	{["address"]=0xE9BC, ["name"]="Link's House",	["type"]="Chest"},
	{["address"]=0xE9CE, ["name"]="Kakariko Tavern",	["type"]="Chest"},
	{["address"]=0xE9E9, ["name"]="Chicken House",	["type"]="Chest"},
	{["address"]=0xE9F2, ["name"]="Aginah's Cave",	["type"]="Chest"},
	{["address"]=0xEA82, ["name"]="Sahasrahla's Hut - Left",	["type"]="Chest"},
	{["address"]=0xEA85, ["name"]="Sahasrahla's Hut - Middle",	["type"]="Chest"},
	{["address"]=0xEA88, ["name"]="Sahasrahla's Hut - Right",	["type"]="Chest"},
	{["address"]=0xEA8E, ["name"]="Kakriko Well - Top",	["type"]="Chest"},
	{["address"]=0xEA91, ["name"]="Kakriko Well - Left",	["type"]="Chest"},
	{["address"]=0xEA94, ["name"]="Kakriko Well - Middle",	["type"]="Chest"},
	{["address"]=0xEA97, ["name"]="Kakriko Well - Right",	["type"]="Chest"},
	{["address"]=0xEA9A, ["name"]="Kakriko Well - Bottom",	["type"]="Chest"},
	{["address"]=0xEB0F, ["name"]="Blind's Hideout - Top",	["type"]="Chest"},
	{["address"]=0xEB12, ["name"]="Blind's Hideout - Left",	["type"]="Chest"},
	{["address"]=0xEB15, ["name"]="Blind's Hideout - Right",	["type"]="Chest"},
	{["address"]=0xEB18, ["name"]="Blind's Hideout - Far Left",	["type"]="Chest"},
	{["address"]=0xEB1B, ["name"]="Blind's Hideout - Far Right",	["type"]="Chest"},
	{["address"]=0xEB3F, ["name"]="Pegasus Rocks",	["type"]="Chest"},
	{["address"]=0xEB42, ["name"]="Mini Moldorm Cave - Far Left",	["type"]="Chest"},
	{["address"]=0xEB45, ["name"]="Mini Moldorm Cave - Left",	["type"]="Chest"},
	{["address"]=0xEB48, ["name"]="Mini Moldorm Cave - Right",	["type"]="Chest"},
	{["address"]=0xEB4B, ["name"]="Mini Moldorm Cave - Far Right",	["type"]="Chest"},
	{["address"]=0xEB4E, ["name"]="Ice Rod Cave",	["type"]="Chest"},
	{["address"]=0x2EB18, ["name"]="Bottle Merchant",	["type"]="Npc"},
	{["address"]=0x2F1FC, ["name"]="Sahasrahla",	["type"]="Npc"},
	{["address"]=0x180015, ["name"]="Magic Bat",	["type"]="Npc"},
	{["address"]=0x339CF, ["name"]="Sick Kid",	["type"]="Npc\BugCatchingKid"},
	{["address"]=0x33E7D, ["name"]="Hobo",	["type"]="Npc"},
	{["address"]=0x180017, ["name"]="Bombos Tablet",	["type"]="Drop\Bombos"},
	{["address"]=0xEE1C3, ["name"]="King Zora",	["type"]="Npc\Zora"},
	{["address"]=0x180000, ["name"]="Lost Woods Hideout",	["type"]="Standing"},
	{["address"]=0x180001, ["name"]="Lumberjack Tree",	["type"]="Standing"},
	{["address"]=0x180003, ["name"]="Cave 45",	["type"]="Standing"},
	{["address"]=0x180004, ["name"]="Graveyard Ledge",	["type"]="Standing"},
	{["address"]=0x180005, ["name"]="Checkerboard Cave",	["type"]="Standing"},
	{["address"]=0x180010, ["name"]="Mini Moldorm Cave - NPC",	["type"]="Npc"},
	{["address"]=0x180012, ["name"]="Library",	["type"]="Dash"},
	{["address"]=0x180013, ["name"]="Mushroom",	["type"]="Standing"},
	{["address"]=0x180014, ["name"]="Potion Shop",	["type"]="Npc\Witch"},
	{["address"]=0x180142, ["name"]="Maze Race",	["type"]="Standing"},
	{["address"]=0x180143, ["name"]="Desert Ledge",	["type"]="Standing"},
	{["address"]=0x180144, ["name"]="Lake Hylia Island",	["type"]="Standing"},
	{["address"]=0x180145, ["name"]="Sunken Treasure",	["type"]="Standing"},
	{["address"]=0x180149, ["name"]="Zora's Ledge",	["type"]="Standing"},
	{["address"]=0x18014A, ["name"]="Flute Spot",	["type"]="Dig\HauntedGrove"},
	{["address"]=0xE9B0, ["name"]="Waterfall Fairy - Left",	["type"]="Chest"},
	{["address"]=0xE9D1, ["name"]="Waterfall Fairy - Right",	["type"]="Chest"},
	{["address"]=0xE9A4, ["name"]="Ice Palace - Big Key Chest",	["type"]="Chest"},
	{["address"]=0xE9D4, ["name"]="Ice Palace - Compass Chest",	["type"]="Chest"},
	{["address"]=0xE9DD, ["name"]="Ice Palace - Map Chest",	["type"]="Chest"},
	{["address"]=0xE9E0, ["name"]="Ice Palace - Spike Room",	["type"]="Chest"},
	{["address"]=0xE995, ["name"]="Ice Palace - Freezor Chest",	["type"]="Chest"},
	{["address"]=0xE9E3, ["name"]="Ice Palace - Iced T Room",	["type"]="Chest"},
	{["address"]=0xE9AA, ["name"]="Ice Palace - Big Chest",	["type"]="BigChest"},
	{["address"]=0x180157, ["name"]="Ice Palace - Kholdstare",	["type"]="Drop"},
	{["address"]=0xEAB5, ["name"]="Castle Tower - Room 03",	["type"]="Chest"},
	{["address"]=0xEAB2, ["name"]="Castle Tower - Dark Maze",	["type"]="Chest"},
	{["address"]=0xEA79, ["name"]="Sanctuary",	["type"]="Chest"},
	{["address"]=0xEB5D, ["name"]="Sewers - Secret Room - Left",	["type"]="Chest"},
	{["address"]=0xEB60, ["name"]="Sewers - Secret Room - Middle",	["type"]="Chest"},
	{["address"]=0xEB63, ["name"]="Sewers - Secret Room - Right",	["type"]="Chest"},
	{["address"]=0xE96E, ["name"]="Sewers - Dark Cross",	["type"]="Chest"},
	{["address"]=0xE974, ["name"]="Hyrule Castle - Boomerang Chest",	["type"]="Chest"},
	{["address"]=0xEB0C, ["name"]="Hyrule Castle - Map Chest",	["type"]="Chest"},
	{["address"]=0xEB09, ["name"]="Hyrule Castle - Zelda's Cell",	["type"]="Chest"},
	{["address"]=0x180161, ["name"]="Ganon's Tower - Bob's Torch",	["type"]="Dash"},
	{["address"]=0xEAB8, ["name"]="Ganon's Tower - DMs Room - Top Left",	["type"]="Chest"},
	{["address"]=0xEABB, ["name"]="Ganon's Tower - DMs Room - Top Right",	["type"]="Chest"},
	{["address"]=0xEABE, ["name"]="Ganon's Tower - DMs Room - Bottom Left",	["type"]="Chest"},
	{["address"]=0xEAC1, ["name"]="Ganon's Tower - DMs Room - Bottom Right",	["type"]="Chest"},
	{["address"]=0xEAC4, ["name"]="Ganon's Tower - Randomizer Room - Top Left",	["type"]="Chest"},
	{["address"]=0xEAC7, ["name"]="Ganon's Tower - Randomizer Room - Top Right",	["type"]="Chest"},
	{["address"]=0xEACA, ["name"]="Ganon's Tower - Randomizer Room - Bottom Left",	["type"]="Chest"},
	{["address"]=0xEACD, ["name"]="Ganon's Tower - Randomizer Room - Bottom Right",	["type"]="Chest"},
	{["address"]=0xEAD0, ["name"]="Ganon's Tower - Firesnake Room",	["type"]="Chest"},
	{["address"]=0xEAD3, ["name"]="Ganon's Tower - Map Chest",	["type"]="Chest"},
	{["address"]=0xEAD6, ["name"]="Ganon's Tower - Big Chest",	["type"]="BigChest"},
	{["address"]=0xEAD9, ["name"]="Ganon's Tower - Hope Room - Left",	["type"]="Chest"},
	{["address"]=0xEADC, ["name"]="Ganon's Tower - Hope Room - Right",	["type"]="Chest"},
	{["address"]=0xEADF, ["name"]="Ganon's Tower - Bob's Chest",	["type"]="Chest"},
	{["address"]=0xEAE2, ["name"]="Ganon's Tower - Tile Room",	["type"]="Chest"},
	{["address"]=0xEAE5, ["name"]="Ganon's Tower - Compass Room - Top Left",	["type"]="Chest"},
	{["address"]=0xEAE8, ["name"]="Ganon's Tower - Compass Room - Top Right",	["type"]="Chest"},
	{["address"]=0xEAEB, ["name"]="Ganon's Tower - Compass Room - Bottom Left",	["type"]="Chest"},
	{["address"]=0xEAEE, ["name"]="Ganon's Tower - Compass Room - Bottom Right",	["type"]="Chest"},
	{["address"]=0xEAF1, ["name"]="Ganon's Tower - Big Key Chest",	["type"]="Chest"},
	{["address"]=0xEAF4, ["name"]="Ganon's Tower - Big Key Room - Left",	["type"]="Chest"},
	{["address"]=0xEAF7, ["name"]="Ganon's Tower - Big Key Room - Right",	["type"]="Chest"},
	{["address"]=0xEAFD, ["name"]="Ganon's Tower - Mini Helmasaur Room - Left",	["type"]="Chest"},
	{["address"]=0xEB00, ["name"]="Ganon's Tower - Mini Helmasaur Room - Right",	["type"]="Chest"},
	{["address"]=0xEB03, ["name"]="Ganon's Tower - Pre-Moldorm Chest",	["type"]="Chest"},
	{["address"]=0xEB06, ["name"]="Ganon's Tower - Moldorm Chest",	["type"]="Chest"},
	{["address"]=0x348FF, ["name"]="Waterfall Bottle",	["type"]="Fountain"},
	{["address"]=0x3493B, ["name"]="Pyramid Bottle",	["type"]="Fountain"},
	{["address"]=0xE977, ["name"]="Eastern Palace - Compass Chest",	["type"]="Chest"},
	{["address"]=0xE97D, ["name"]="Eastern Palace - Big Chest",	["type"]="BigChest"},
	{["address"]=0xE9B3, ["name"]="Eastern Palace - Cannonball Chest",	["type"]="Chest"},
	{["address"]=0xE9B9, ["name"]="Eastern Palace - Big Key Chest",	["type"]="Chest"},
	{["address"]=0xE9F5, ["name"]="Eastern Palace - Map Chest",	["type"]="Chest"},
	{["address"]=0x180150, ["name"]="Eastern Palace - Armos Knights",	["type"]="Drop"},
	{["address"]=0xE98F, ["name"]="Desert Palace - Big Chest",	["type"]="BigChest"},
	{["address"]=0xE9B6, ["name"]="Desert Palace - Map Chest",	["type"]="Chest"},
	{["address"]=0x180160, ["name"]="Desert Palace - Torch",	["type"]="Dash"},
	{["address"]=0xE9C2, ["name"]="Desert Palace - Big Key Chest",	["type"]="Chest"},
	{["address"]=0xE9CB, ["name"]="Desert Palace - Compass Chest",	["type"]="Chest"},
	{["address"]=0x180151, ["name"]="Desert Palace - Lanmolas'",	["type"]="Drop"},
	{["address"]=0xF69FA, ["name"]="Old Man",	["type"]="Npc"},
	{["address"]=0x180002, ["name"]="Spectacle Rock Cave",	["type"]="Standing"},
	{["address"]=0x180016, ["name"]="Ether Tablet",	["type"]="Drop\Ether"},
	{["address"]=0x180140, ["name"]="Spectacle Rock",	["type"]="Standing"},
	{["address"]=0xE9BF, ["name"]="Spiral Cave",	["type"]="Chest"},
	{["address"]=0xE9C5, ["name"]="Mimic Cave",	["type"]="Chest"},
	{["address"]=0xEB2A, ["name"]="Paradox Cave Lower - Far Left",	["type"]="Chest"},
	{["address"]=0xEB2D, ["name"]="Paradox Cave Lower - Left",	["type"]="Chest"},
	{["address"]=0xEB30, ["name"]="Paradox Cave Lower - Right",	["type"]="Chest"},
	{["address"]=0xEB33, ["name"]="Paradox Cave Lower - Far Right",	["type"]="Chest"},
	{["address"]=0xEB36, ["name"]="Paradox Cave Lower - Middle",	["type"]="Chest"},
	{["address"]=0xEB39, ["name"]="Paradox Cave Upper - Left",	["type"]="Chest"},
	{["address"]=0xEB3C, ["name"]="Paradox Cave Upper - Right",	["type"]="Chest"},
	{["address"]=0x180141, ["name"]="Floating Island",	["type"]="Standing"},
	{["address"]=0xEB1E, ["name"]="Hype Cave - Top",	["type"]="Chest"},
	{["address"]=0xEB21, ["name"]="Hype Cave - Middle Right",	["type"]="Chest"},
	{["address"]=0xEB24, ["name"]="Hype Cave - Middle Left",	["type"]="Chest"},
	{["address"]=0xEB27, ["name"]="Hype Cave - Bottom",	["type"]="Chest"},
	{["address"]=0x330C7, ["name"]="Stumpy",	["type"]="Npc"},
	{["address"]=0x180011, ["name"]="Hype Cave - NPC",	["type"]="Npc"},
	{["address"]=0x180148, ["name"]="Digging Game",	["type"]="Dig"},
	{["address"]=0xE9EC, ["name"]="Brewery",	["type"]="Chest"},
	{["address"]=0xE9EF, ["name"]="C-Shaped House",	["type"]="Chest"},
	{["address"]=0xEDA8, ["name"]="Chest Game",	["type"]="Chest"},
	{["address"]=0x180006, ["name"]="Hammer Pegs",	["type"]="Standing"},
	{["address"]=0x180146, ["name"]="Bumper Cave",	["type"]="Standing"},
	{["address"]=0x33D68, ["name"]="Purple Chest",	["type"]="Npc"},
	{["address"]=0xEE185, ["name"]="Catfish",	["type"]="Standing"},
	{["address"]=0x180147, ["name"]="Pyramid",	["type"]="Standing"},
	{["address"]=0x180028, ["name"]="Pyramid Fairy - Sword",	["type"]="Trade"},
	{["address"]=0x34914, ["name"]="Pyramid Fairy - Bow",	["type"]="Trade"},
	{["address"]=0xEA73, ["name"]="Mire Shed - Left",	["type"]="Chest"},
	{["address"]=0xEA76, ["name"]="Mire Shed - Right",	["type"]="Chest"},
	{["address"]=0xEA8B, ["name"]="Spike Cave",	["type"]="Chest"},
	{["address"]=0xEA7C, ["name"]="Superbunny Cave - Top",	["type"]="Chest"},
	{["address"]=0xEA7F, ["name"]="Superbunny Cave - Bottom",	["type"]="Chest"},
	{["address"]=0xEB51, ["name"]="Hookshot Cave - Top Right",	["type"]="Chest"},
	{["address"]=0xEB54, ["name"]="Hookshot Cave - Top Left",	["type"]="Chest"},
	{["address"]=0xEB57, ["name"]="Hookshot Cave - Bottom Left",	["type"]="Chest"},
	{["address"]=0xEB5A, ["name"]="Hookshot Cave - Bottom Right",	["type"]="Chest"},

	{["address"]=0x18002A, ["name"]="Blacksmith",	["type"]="Npc"},
	{["address"]=0x3355C, ["name"]="Blacksmith",	["type"]="Npc"},
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



local function zeroRising(newValue, prevValue) -- "Allow if replacing 'no item', but not if replacing another item"
	if (newValue ~= 0 and prevValue == 0) then
		return newValue
	else
		return prevVal
	end
end

local function zeroRisingOrUpgradeFlute(newValue, prevValue) -- "Allow if replacing 'no item', but not if replacing another item"
	if ( (newValue ~= 0 and prevValue == 0) or (newValue == 3 and prevValue == 2) ) then
		return newValue
	else
		return prevVal
	end
end

ramItems = {
	-- INVENTORY_SWAP
	[0xF412] = {
		name={"Bird", "Flute", "Shovel", "unknown item", "Magic Powder", "Mushroom", "Magic Boomerang", "Boomerang"},
		type="bit",
		receiveFunc=function(newValue, prevValue) 
			-- If acquired bird, clear flute
			if 0 ~= bit.band(newValue, 0x02) then 
				newValue = bit.band(newValue, 0xFE) 
			end 

			-- FIXME: Do not re-set mushroom bit if mushroom is already given to witch

			-- Mushroom/powder byte is a disaster so set it indirectly when this mask changes
			local mushroomByte = 0xF344
			-- If powder bit went high and no mushroom type item is being held, place powder in inventory
			if 0 ~= bit.band(newValue, 0x10) and 0 == bit.band(prevValue, 0x10) 
			and 0 == readRAM("WRAM", mushroomByte, 1) then
				writeRAM("WRAM", mushroomByte, 1, 0x02)
			end
			-- If mushroom bit went high and no mushroom type item is being held, place mushroom in inventory
			if 0 ~= bit.band(newValue, 0x20) and 0 == bit.band(prevValue, 0x20) 
			and 0 == readRAM("WRAM", mushroomByte, 1) then
				writeRAM("WRAM", mushroomByte, 1, 0x01)
			end

			return newValue
		end
	},

	-- INVENTORY_SWAP_2
	[0xF414] = {
		name={"unknown item", "unknown item", "unknown item", "unknown item", "unknown item", "unknown item", "Silver Arrows", "Bow"},
		type="bit"
	},

	-- NPC_FLAGS
	--[0xF410] = {
	--	name={"an old man home"}, 
	--	mask=0x01, -- Only sync old man
	--	type="bit"
	--},	-- NPC_FLAGS

	[0xF3C5] = {type="num"}, -- "light world progress" needed to activate sword

	[0xF340] = {type="num", receiveFunc=zeroRising}, -- Bows, tracked in INVENTORY_SWAP_2 but must be nonzero to appear in inventory
	[0xF341] = {type="num", receiveFunc=zeroRising}, -- Boomerangs, tracked in INVENTORY_SWAP
	[0xF342] = {name="Hookshot", type="bool"},
	[0xF345] = {name="Fire Rod", type="bool"},
	[0xF346] = {name="Ice Rod", type="bool"},
	[0xF347] = {name="Bombos", type="bool"},
	[0xF348] = {name="Ether", type="bool"},
	[0xF349] = {name="Quake", type="bool"},
	[0xF34A] = {name="Lantern", type="bool"},
	[0xF34B] = {name="Hammer", type="bool"},
	-- Note this doesn't need to happen in INVENTORY_SWAP receiveTrigger bc you can only upgrade the flute while holding it
	[0xF34C] = {type="num", receiveFunc=zeroRisingOrUpgradeFlute},       -- Shovel flute etc, tracked in INVENTORY_SWAP
	[0xF34D] = {name="Net", type="bool"},
	[0xF34E] = {name="Book", type="bool"},
	[0xF34F] = {type="byte"}, -- Bottle count
	[0xF350] = {name="Red Cane", type="bool"},
	[0xF351] = {name="Blue Cane", type="bool"},
	[0xF352] = {name="Cape", type="bool"},
	[0xF353] = {name="Mirror", type="bool"},
	[0xF354] = {name="Gloves", type="bool"},
	[0xF355] = {name="Boots", type="bool"},
	[0xF356] = {name="Flippers", type="bool"},
	[0xF357] = {name="Pearl", type="bool"},
	[0xF359] = {name={[0]="Swordless", "Fighter's Sword", "Master Sword", "Tempered Sword", "Golden Sword"}, type="delta", mask=0x07},
	[0xF416] = {type="num", mask=0xC0}, -- Progressive shield
	[0xF35A] = {name={[0]="No Shield", "Shield", "Fire Shield", "Mirror Shield"}, type="delta"},
	[0xF35B] = {name={[0]="Green Mail", "Blue Mail", "Red Mail"}, type="delta"},
	[0xF35C] = {name="Bottle", type="num"}, 
	[0xF35D] = {name="Bottle", type="num"},
	[0xF35E] = {name="Bottle", type="num"},
	[0xF35F] = {name="Bottle", type="num"},
	[0xF364] = {name={"unused Compass", "unused Compass", "Ganon's Tower Compass", "Turtle Rock Compass", "Thieves Towen Compass", "Tower of Hera Compass", "Ice Palace Compass", "Skull Woods Compass"}, type="bit"},
	[0xF365] = {name={"Misery Mire Compass", "Palace of Darkness Compass", "Swamp Palace Compass", "Agahnim's Tower Compass", "Desert Palace Compass", "Eastern Palace Compass", "Hyrule Castle Compass", "Sewer Passage Compass"}, type="bit"},
	[0xF366] = {name={"unused Boss Key", "unused Boss Key", "Ganon's Tower Boss Key", "Turtle Rock Boss Key", "Thieves Towen Boss Key", "Tower of Hera Boss Key", "Ice Palace Boss Key", "Skull Woods Boss Key"}, type="bit"},
	[0xF367] = {name={"Misery Mire Boss Key", "Palace of Darkness Boss Key", "Swamp Palace Boss Key", "Agahnim's Tower Boss Key", "Desert Palace Boss Key", "Eastern Palace Boss Key", "Hyrule Castle Boss Key", "Sewer Passage Boss Key"}, type="bit"},
	[0xF368] = {name={"unused Map", "unused Map", "Ganon's Tower Map", "Turtle Rock Map", "Thieves Towen Map", "Tower of Hera Map", "Ice Palace Map", "Skull Woods Map"}, type="bit"},
	[0xF369] = {name={"Misery Mire Map", "Palace of Darkness Map", "Swamp Palace Map", "Agahnim's Tower Map", "Desert Palace Map", "Eastern Palace Map", "Hyrule Castle Map", "Sewer Passage Map"}, type="bit"},
	[0xF379] = {type="bit", mask=0x06}, -- Abilities
	[0xF374] = {name={"Red Pendant", "Blue Pendant", "Green Pendant"}, type="bit"},
	[0xF37A] = {name={"Crystal 6", "Crystal 1", "Crystal 5", "Crystal 7", "Crystal 2", "Crystal 4", "Crystal 3", "unused"}, type="bit"},
	[0xF37B] = {name={[0]="Normal Magic", "1/2 Magic", "1/4 Magic"}, type="num"},

	-- Ammo values
	[0xF360] = {type="delta", size=2}, -- Current Rupees
	[0xF36A] = {type="delta"}, -- Wishing Pond Rupees
	[0xF36C] = {type="delta"}, -- HP Max
	[0xF36D] = {type="delta"}, -- HP Current
	[0xF36E] = {type="delta"}, -- MP
	[0xF370] = {type="delta"}, -- Bomb upgrades
	[0xF371] = {type="delta"}, -- Arrow upgrades
	[0xF377] = {type="delta"}, -- Arrows
	[0xF343] = {type="delta"} -- Bombs

	--TODO Keys
}


function getGUImessage(address, prevVal, newVal, user)
	local name = ramItems[address].name
	if name then
		if ramItems[address].type == "bool" then				
			gui.addmessage(user .. ": " .. name .. (newVal == 0 and 'Removed' or ''))
		elseif ramItems[address].type == "num" then
			if (type(name) == 'string') then
				gui.addmessage(user .. ": " .. name .. " = " .. newVal)
			else
				gui.addmessage(user .. ": " .. (name[newVal] or (name[0] .. " = " .. newVal)))
			end
		elseif ramItems[address].type == "bit" then
			local bitMask = 0x01
			for b=1,8 do
				local newBit = (bit.band(newVal, bitMask) > 0)
				local prevBit = (bit.band(prevVal, bitMask) > 0)
				bitMask = bit.lshift(bitMask, 1)

				if (newBit ~= prevBit) then
					if (type(name) == 'string') then
						gui.addmessage(user .. ": " .. name .. " flag " .. b .. (newBit and '' or ' Off'))
					else
						gui.addmessage(user .. ": " .. (name[b] or name[1]) .. (newBit and '' or ' Off'))
					end
				end
			end
		elseif ramItems[address].type == "delta" then
			local delta = newVal - prevVal
			if (type(name) == 'string') then
				gui.addmessage(user .. ": " .. name .. (delta > 0 and " +" or " ") .. delta)
			else
				gui.addmessage(user .. ": " .. (name[newVal] or (name[0] .. (delta > 0 and " +" or " ") .. delta)))
			end
		else 
			gui.addmessage("Unknown item ram type")
		end
	end
end


function getRAM() 
	newRAM = {}
	for address, item in pairs(ramItems) do
		if (not item.size) then
			item.size = 1
		end

		local ramval = readRAM("WRAM", address, item.size)

		if (item.mask) then
			ramval = bit.band(ramval, item.mask)
		end

		newRAM[address] = ramval
	end

	return newRAM
end


function eventRAMchanges(prevRAM, newRAM)
	local ramevents = {}
	local changes = false

	for address, val in pairs(newRAM) do
		if (prevRAM[address] ~= val) then
			getGUImessage(address, prevRAM[address], val, config.user)
			if ramItems[address].type == "bool" then
				ramevents[address] = (val ~= 0)
				changes = true
			elseif ramItems[address].type == "num" then
				ramevents[address] = val				
				changes = true
			elseif ramItems[address].type == "bit" then
				local changedBits = {}
				local bitMask = 0x01
				for b=1,8 do
					local prevval = prevRAM[address]

					newBit = (bit.band(val, bitMask) > 0)
					prevBit = (bit.band(prevval, bitMask) > 0)
					bitMask = bit.lshift(bitMask, 1)

					if (newBit ~= prevBit) then
						changedBits[b] = newBit
					end
				end
				ramevents[address] = changedBits
				changes = true
			elseif ramItems[address].type == "delta" then
				ramevents[address] = val - prevRAM[address]
				changes = true
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


function setRAMchanges(prevRAM, their_user, newEvents)
	for address, val in pairs(newEvents) do
		local newval

		if ramItems[address].type == "bool" then
			newval = (val and 1 or 0)
		elseif ramItems[address].type == "num" then
			newval = val
		elseif ramItems[address].type == "bit" then
			newval = prevRAM[address]
			for b, bitval in pairs(val) do
				local bitSet = bit.lshift(0x01, b)
				local bitMask = bit.bxor(0xFF, bitSet)

				newval = bit.band(newval, bitMask)
				if bitval then
					newval = bit.bor(newval, bitSet)
				end
			end
		elseif ramItems[address].type == "delta" then
			newval = prevRAM[address] + val
		else 
			printOutput("Unknown item ram type")
			newval = prevRAM[address]
		end

		if (ramItems[address].receiveFunc) then
			newval = ramItems[address].receiveFunc(newval, prevRAM[address])
		end

		if (ramItems[address].mask) then
			local xMask = bit.bxor(ramItems[address].mask, 0xFF)
			local prevval = readRAM("WRAM", address, ramItems[address].size)

			prevval = bit.band(prevval, xMask)
			newval = bit.band(newval, ramItems[address].mask)
			prevRAM[address] = newval

			newval = bit.bor(prevval, newval)
		else 
			prevRAM[address] = newval
		end
		getGUImessage(address, prevRAM[address], newval, their_user)
		writeRAM("WRAM", address, ramItems[address].size, newval)
	end	
end

local lttp_ram = {}
local prevRAM = nil


local splitItems = {}
function removeItems()
	for ID, location in ipairs(locations) do

		if (location.oldItem) then
			writeRAM("CARTROM", location.address, 1, location.oldItem)
		else
			location.oldItem = readRAM("CARTROM", location.address, 1)
		end

		if (items[location.oldItem]) and (splitItems[ID] ~= my_ID) then
			local prevItem = readRAM("CARTROM", location.address, 1)
			if items[prevItem] then
				writeRAM("CARTROM", location.address, 1, 0x5A) -- Remove item
			end
		end
	end
end


lttp_ram.itemcount = 0
for _,_ in pairs(locations) do lttp_ram.itemcount = lttp_ram.itemcount + 1 end

-- Gets a message to send to the other player of new changes
-- Returns the message as a dictionary object
-- Returns false if no message is to be send
function lttp_ram.getMessage()
	local newRAM = getRAM()
	if (prevRAM == nil) then
		prevRAM = newRAM
	end

	local message = eventRAMchanges(prevRAM, newRAM)

	-- Update the frame pointer
	prevRAM = newRAM

	return message
end

-- Process a message from another player and update RAM
function lttp_ram.processMessage(their_user, message)
	if message["i"] then
		splitItems = message["i"]
		message["i"] = nil
		removeItems()
	end

	setRAMchanges(prevRAM, their_user, message)
end

return lttp_ram