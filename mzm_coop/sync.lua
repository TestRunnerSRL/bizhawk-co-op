--This file implements the logic that syncs two player's inputs
--author: TheOnlyOne and TestRunner
local sync = {}

local addresses = {}
addresses.maxHP = 0x1530
addresses.maxMissiles = 0x1532
addresses.maxSupers = 0x1534
addresses.HP = 0x1536
addresses.Missiles = 0x1538
addresses.Supers = 0x153A
addresses.EquipmentA = 0x153C
addresses.EquipmentB = 0x153E

local RAM_Values = {}

--Load required files before attempting to sync
function sync.initialize() 
  memory.usememorydomain("IWRAM") 
  for i, address in pairs(addresses) do
    RAM_Values[address] = memory.read_u16_le(address)
  end
end

local messenger = require("mzm_coop\\messenger")

--makes sure that configurations are consistent between the two players
function sync.syncconfig(client_socket, default_player)
  printOutput("Checking that configurations are consistent (this may take a few seconds...)")
  
  local sha1 = require("mzm_coop\\sha1")

  --construct a value representing the sync code that is in use
  local sync_code = ""
  for line in io.lines("mzm_coop\\sync.lua") do sync_code = sync_code .. line .. "\n" end
  for line in io.lines("mzm_coop\\messenger.lua") do sync_code = sync_code .. line .. "\n" end
  local sync_hash = sha1.sha1(sync_code)

  --send the configuration
  messenger.send(client_socket, messenger.CONFIG, sync_hash)

  --receive their configuration
  local received_message_type, received_data = messenger.receive(client_socket)
  if (received_message_type ~= messenger.CONFIG) then
    error("Unexpected message type received.")
  end
  local their_sync_hash = received_data[1]

  --check consistency of configurations
  --check sync code
  if (sync_hash ~= their_sync_hash) then
    printOutput("You are not both using the same sync code (perhaps one of you is using an older version?)")
    printOutput("Make sure your sync code is the same and try again.")
    error("Configuration consistency check failed.")
  end
end

local received_message_type, received_data
local timeout_frames = 0

--shares the input between two players, making sure that the same input is
--pressed for both players on every frame. Sends and receives instructions
--that must be performed simultaneously; such as pausing and saving
function sync.syncRAM(client_socket)
  while true do
    --Send Quit request
    if sendMessage["Quit"] == true then 
      sendMessage["Quit"] = nil

      syncStatus = "Idle"
      messenger.send(client_socket, messenger.QUIT)
      error("You closed the connection.")
    end

    --Send inputs if not paused
    if (syncStatus == "Play") then
      local new_RAM = {}
      local newsend = false
      for i, address in pairs(addresses) do
        local value = memory.read_u16_le(address)
        if (value ~= RAM_Values[address]) then
          new_RAM[address] = value;
          newsend = true
        end
        RAM_Values[address] = value;
      end

      if (new_RAM ~= nil and newsend) then
        messenger.send(client_socket, messenger.MEMORY, new_RAM)
      end
    end

    --receive this frame's input from the other player and other messages
    
    received_message_type, received_data = messenger.receive(client_socket, true)

    if (received_message_type == messenger.MEMORY) then
      --we received memory
      timeout_frames = 0

      for adr, mem in pairs(received_data) do
        memory.write_u16_le(adr, mem)
      end
    elseif (received_message_type == messenger.QUIT) then
      --we received quit
      error("They closed the connection.")
    elseif (received_message_type == nil) then
      --If no message if received, then yield and try again
      --timeout_frames = timeout_frames + 1

      --Timeout the connection if no message in 300 frames
      if (timeout_frames > 300) then
        error("Connection Timeout")
      end
    else
      error("Unexpected message type received.")
    end

    coroutine.yield()
  end
end

return sync