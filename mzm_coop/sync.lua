--This file implements the logic that syncs two player's inputs
--author: TheOnlyOne and TestRunner
local sync = {}

local messenger = require("mzm_coop\\messenger")
local ram_controller = require("mzm_coop\\mzm_ram")

my_ID = nil

--makes sure that configurations are consistent between the two players
function sync.syncconfig(client_socket, their_id)
  printOutput("Checking configuration consistency...")
  
  local sha1 = require("mzm_coop\\sha1")

  --construct a value representing the sync code that is in use
  local sync_code = ""
  for line in io.lines("mzm_coop\\sync.lua") do sync_code = sync_code .. line .. "\n" end
  for line in io.lines("mzm_coop\\messenger.lua") do sync_code = sync_code .. line .. "\n" end
  local sync_hash = sha1.sha1(sync_code)

  --send the configuration
  messenger.send(client_socket, messenger.CONFIG, sync_hash, their_id)

  --receive their configuration
  local received_message_type, received_data = messenger.receive(client_socket)
  if (received_message_type ~= messenger.CONFIG) then
    printOutput("Configuration consistency check failed: Unexpected message type received.")
    return false
  end
  local their_sync_hash = received_data[1]
  local my_new_id = received_data[2]

  --check consistency of configurations
  --check sync code
  if (sync_hash ~= their_sync_hash) then
    printOutput("Configuration consistency check failed: Bad hash")
    printOutput("You are not both using the same sync code (perhaps one of you is using an older version?)")
    printOutput("Make sure your sync code is the same and try again.")
    return false
  end

  if my_new_id ~= nil then
    my_ID = my_new_id
  elseif their_id ~= nil then
    my_ID = 1
  end

  printOutput("Configuration consistency check passed")
  return true
end


function sync.sendItems(itemlist)
  for _,client in pairs(host.clients) do
    messenger.send(client, messenger.RAMEVENT, {["i"]=itemlist})
  end 
  ram_controller.processMessage({["i"]=itemlist})

end




--shares the input between two players, making sure that the same input is
--pressed for both players on every frame. Sends and receives instructions
--that must be performed simultaneously; such as pausing and saving
function sync.syncRAM(clients)
  while true do
    --Send Quit request
    if sendMessage["Quit"] == true then 
      sendMessage["Quit"] = nil

      for _,client in pairs(clients) do
        messenger.send(client, messenger.QUIT)
      end
      error("You closed the connection.")
    end

    local ram_message = ram_controller.getMessage()
    if ram_message then
      for _,client in pairs(clients) do
        messenger.send(client, messenger.RAMEVENT, ram_message)
      end
    end

    --receive this frame's input from the other player and other messages
    for clientID, client in pairs(clients) do
      local received_message_type, received_data = messenger.receive(client, true)

      -- echo messages
      if (received_message_type ~= nil) then
        for otherClientID, otherClient in pairs(clients) do
          if (otherClientID ~= clientID) then
            messenger.send(otherClient, received_message_type, received_data)
          end
        end
      end

      if (received_message_type == messenger.MEMORY) then
        --we received memory
        for adr, mem in pairs(received_data) do
          memory.write_u16_le(adr, mem)
        end
      elseif (received_message_type == messenger.RAMEVENT) then
        --we received memory
        ram_controller.processMessage(received_data)
      elseif (received_message_type == messenger.QUIT) then
        --we received quit
        error("They closed the connection.")
      elseif (received_message_type == nil) then
        --no message received
      else
        error("Unexpected message type received.")
      end
    end

    clients = coroutine.yield()
  end
end

return sync