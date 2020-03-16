--This file implements the logic that syncs two player's inputs
--author: TheOnlyOne and TestRunner
local sync = {}

local messenger = require("bizhawk-co-op\\messenger")
local sha1 = require("bizhawk-co-op\\sha1")
local ram_controller
local sync_hashes = {}

my_ID = nil


function sync.loadramcontroller()
  local require_status
  require_status, ram_controller = pcall(function()
    return dofile("bizhawk-co-op\\ramcontroller\\" .. config.ramcode)
  end)
  if not require_status then
    printOutput("The RAM controller file could not be loaded: " .. ram_controller)
    return false
  end
  if (ram_controller.getMessage == nil) or
          (ram_controller.processMessage == nil) or
          (ram_controller.itemcount == nil) then
    printOutput("The RAM controller file is not valid.")
    return false
  end

  return ram_controller
end


--makes sure that configurations are consistent between the two players
function sync.syncconfig(client_socket, their_id)
  printOutput("Checking configuration consistency...")

  --construct a value representing the sync code that is in use. result are
  --cached to avoid recomputation when reconnecting.
  if sync_hashes[config.ramcode] == nil then
    local files = {
      "bizhawk-co-op.lua",
      "bizhawk-co-op\\host.lua",
      "bizhawk-co-op\\messenger.lua",
      "bizhawk-co-op\\sync.lua",
      "bizhawk-co-op\\ramcontroller\\" .. config.ramcode,
    }
    local lines = {}
    for _, file in ipairs(files) do
      for line in io.lines(file) do lines[#lines + 1] = line end
    end
    sync_hashes[config.ramcode] = sha1.sha1(table.concat(lines, "\n") .. "\n")
  end
  local sync_hash = sync_hashes[config.ramcode]

  -- only host sends config
  if (their_id == nil) then
    config.ramconfig = nil
  end

  --send the configuration
  messenger.send(client_socket, config.user, messenger.CONFIG, sync_hash, their_id, config.ramconfig)

  --receive their configuration
  local received_message_type, their_user, received_data = messenger.receive(client_socket)
  if (received_message_type == messenger.ERROR) then
    printOutput("Configuration consistency check failed: " .. their_user)
    return false
  end

  if (received_message_type ~= messenger.CONFIG) then
    printOutput("Configuration consistency check failed: Unexpected message type received.")
    return false
  end

  if (host.users[their_user]) then
    printOutput("Configuration consistency check failed: Username in use")
    return false
  end

  -- send our player number
  messenger.send(client_socket, config.user, messenger.PLAYERNUMBER, config.user, forms.gettext(formPlayerNumber))

  -- receive their player number, if nil then it is taken already
  local _, __, pnum_data = messenger.receive(client_socket)

  if (pnum_data == nil) then
    printOutput("Configuration consistency check failed: Player Number in use")
    return false
  end


  local their_sync_hash = received_data[1]
  local my_new_id = received_data[2]
  local newconfig = received_data[3]

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
    host.hostname = their_user
  elseif their_id ~= nil then
    my_ID = 1
    host.hostname = config.user
  end

  if newconfig ~= nil then
    config.ramconfig = newconfig
  end

  printOutput("Configuration consistency check passed")

  return their_user
end


function sync.sendItems(itemlist)
  for _,client in pairs(host.clients) do
    messenger.send(client, config.user, messenger.RAMEVENT, {["i"]=itemlist})
  end
  ram_controller.processMessage(config.user, {["i"]=itemlist})
end

function sync.sendPlayerList(playerlist)
  for _,client in pairs(host.clients) do
    messenger.send(client, config.user, messenger.PLAYERLIST, {["l"]=playerlist})
  end
end

function sync.kickPlayer()
  if host.users[forms.gettext(kickPlayerSelect)] ~= 1 then
    printOutput("You kicked " .. forms.gettext(kickPlayerSelect))
    gui.addmessage("You kicked " .. forms.gettext(kickPlayerSelect))
    messenger.send(host.clients[host.users[forms.gettext(kickPlayerSelect)]], config.user, messenger.KICKPLAYER)
  else
    printOutput("You can not kick yourself.")
  end
end

function sync.readyToggle()
  local status = forms.gettext(readyToggle)

  if host.status == "Host" then
    host.playerlist[config.user]['status'] = status
    sync.updatePlayerList(host.playerlist)

    if getTableSize(host.playerlist) > 1 then
      sync.sendPlayerList(host.playerlist)
    end
  else
    messenger.send(host.clients[1], config.user, messenger.PLAYERSTATUS, config.user, status)
  end

  if status == "Ready" then
    forms.settext(readyToggle, "Unready")
  end

  if status == "Unready" then
    forms.settext(readyToggle, "Ready")
  end
end

local close_client = function(clientID, err)
  local their_user = "The other player"
  for name, id in pairs(host.users) do
    if id == clientID then
      their_user = name
      break
    end
  end
  gui.addmessage(their_user .. " is not responding " .. err)
  printOutput("[Error] " .. their_user .. " is not responding " .. err)

  -- close sockets
  if clientID == 1 then
	-- host disconnected, we'll try to reconnect
    host.close(true)
    error("Connection interrupted.")
  else
    -- client disconnected, room is still open
    gui.addmessage(their_user .. " left the room.")
    printOutput(their_user .. " left the room.")
    host.client_ping[clientID] = nil
    host.clients[clientID]:close()
    host.clients[clientID] = nil
    host.users[their_user] = nil
    host.playerlist[their_user] = nil
  end

  if config.user == host.hostname then
    sync.updatePlayerList(host.playerlist)
    sync.sendPlayerList(host.playerlist)
  end
end


local ping_func = function()
  for clientID, client in pairs(host.clients) do
    -- send PING message
    messenger.send(client, config.user, messenger.PING)

    -- check if they have timedout
    host.client_ping[clientID] = (host.client_ping[clientID] or 4) - 1
    if host.client_ping[clientID] <= 0 then
      -- ping timeout
      close_client(clientID, "[PING TIMEOUT]")
    end
  end
  return false
end


function timer_coroutine(time, callback)
  local init = os.time()
  local now

  while true do
    now = os.time()
    if os.difftime(now, init) < time then
      coroutine.yield(false)
    else
      init = now
      coroutine.yield(callback())
    end
  end
end
local ping_timer = coroutine.create(timer_coroutine)
coroutine.resume(ping_timer, 10, ping_func)


--shares the input between two players, making sure that the same input is
--pressed for both players on every frame. Sends and receives instructions
--that must be performed simultaneously; such as pausing and saving
function sync.syncRAM()
  while true do
    -- check for PING TIMEOUT and send PINGS
    if coroutine.status(ping_timer) == "dead" then
      ping_timer = coroutine.create(timer_coroutine)
      coroutine.resume(ping_timer, 1, ping_func)
    else
      local timer_status, err = coroutine.resume(ping_timer)
      if not timer_status then
        printOutput(err)
      end
    end

    --Send Quit request
    if sendMessage["Quit"] == true then
      sendMessage["Quit"] = nil
      local was_kicked = ""

      for _,client in pairs(host.clients) do
        if kicked then
          was_kicked = "was_kicked"
        end

        messenger.send(client, config.user, messenger.QUIT, {["q"]=was_kicked})
      end

      if not kicked then
        gui.addmessage("You closed the connection.")
        host.close()
        error("You closed the connection.")
      else
        gui.addmessage("You were kicked from the room.")
        host.close()
        error("You were kicked from the room.")
      end
    end

    local ram_message = ram_controller.getMessage()
    if ram_message then
      for _,client in pairs(host.clients) do
        messenger.send(client, config.user, messenger.RAMEVENT, ram_message)
      end
    end

    --receive this frame's input from the other player and other messages
    for clientID, client in pairs(host.clients) do
      local received_message_type, their_user, received_data = messenger.receive(client, true)

      -- close client on error
      if (received_message_type == messenger.ERROR) then
        close_client(clientID, their_user)
        break
      end

      -- echo messages
      if (received_message_type ~= nil) then
        for otherClientID, otherClient in pairs(host.clients) do
          if (otherClientID ~= clientID) then
            if received_message_type ~= messenger.PLAYERSTATUS then
              messenger.send(otherClient, their_user, received_message_type, received_data)
            end
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
        ram_controller.processMessage(their_user, received_data)
      elseif (received_message_type == messenger.PLAYERLIST) then
        --we received the playerlist
        sync.updatePlayerList(received_data.l)
      elseif (received_message_type == messenger.QUIT) then
        local was_kicked = received_data.q

        --we received quit
        if their_user == host.hostname then
          -- host sent the message, room is closed
          gui.addmessage(their_user .. " closed the room.")
          host.close()
          error(their_user .. " closed the room.")
        else
          -- client sent the message, room is still open
          if was_kicked == "was_kicked" then
            gui.addmessage(their_user .. " was kicked from the room.")
            printOutput(their_user .. " was kicked from the room.")
          else
            gui.addmessage(their_user .. " left the room.")
            printOutput(their_user .. " left the room.")
          end

          -- disconnect if player is connected directly
          if host.users[their_user] then
            local their_id = host.users[their_user]
            host.client_ping[their_id] = nil
            host.clients[their_id]:close()
            host.clients[their_id] = nil
            host.users[their_user] = nil
            host.playerlist[their_user] = nil
          end
        end
        if config.user == host.hostname then
          host.playerlist[their_user] = nil
          sync.updatePlayerList(host.playerlist)
          sync.sendPlayerList(host.playerlist)
          host.updateHostControls()
        end
      elseif (received_message_type == messenger.PING) then
        host.client_ping[clientID] = 4
      elseif (received_message_type == messenger.KICKPLAYER) then
        kicked = true
        leaveRoom()
      elseif (received_message_type == messenger.PLAYERSTATUS) then
        sync.updatePlayerList(host.playerlist)
        sync.sendPlayerList(host.playerlist)
      elseif (received_message_type == nil) then
        --no message received
      else
        error("Unexpected message type received.")
      end
    end

    coroutine.yield()
  end
end

function sync.updatePlayerList(playerlist)
  host.playerlist = playerlist
  forms.settext(formPlayerList, "")
  local text = ""
  local sortedKeys = getKeysSortedByValue(playerlist, function(a, b) return a.num < b.num end)
  local readyCount = 0
  for _, k in ipairs(sortedKeys) do
    if (playerlist[k]['num'] ~= nil) then
      if playerlist[k]['status'] == "Unready" then
        text = text .. "[ ] P" .. tonumber(playerlist[k]['num']) .. ": " .. k
      end

      if (playerlist[k]['status'] == "Ready") then
        text = text .. "[X] P" .. tonumber(playerlist[k]['num']) .. ": " .. k
        readyCount = readyCount + 1
      end

      text = text .. "\r\n"
    end

    forms.settext(formPlayerList, text)
  end

  forms.settext(formPlayerCount, getTableSize(host.playerlist))
  forms.settext(formReadyCount, tostring(readyCount))
end

return sync