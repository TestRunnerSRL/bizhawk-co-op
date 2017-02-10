--Abstracts message passing between two clients
--author: TheOnlyOne
local messenger = {}

--list of message types
messenger.MEMORY = 0
messenger.CONFIG = 1
messenger.QUIT = 4

--the first character of the message tells what kind of message was sent
local message_type_to_char = {
  [messenger.MEMORY] = "m",
  [messenger.CONFIG] = "c",
  [messenger.QUIT] = "q",
}
--inverse of the previous table
local char_to_message_type = {}
for t, c in pairs(message_type_to_char) do
  char_to_message_type[c] = t
end



--describes how to encode a message for each message type
local encode_message = {

  --an input message expects 2 arguments:
  --a table containing the inputs pressed,
  --and the frame this input should be pressed on
  [messenger.MEMORY] = function(data)
    message = ""
    for adr, val in pairs(data[1]) do
      message = message .. adr .. ":" .. val .. ","
    end
    message = message:sub(1, -2)

    return message
  end,

  --a config message expects 1 arguments:
  --the hash of the code used in gameplay sync
  [messenger.CONFIG] = function(data)
    local sync_hash = data[1]
    local message = sync_hash
    return message
  end,

  --a quit message expects no arguments
  [messenger.QUIT] = function(data)
    return ""
  end
}

--sends a message to the other clients
--client_socket is the socket the message is being sent over
--message_type is one of the types listed above
--the remaining arguments are specific to the type of message being sent
function messenger.send(client_socket, message_type, ...)
  --pack message type-specific arguments into a table
  local data = {...}
  --get the function that should encode the message
  local encoder = encode_message[message_type]
  if (encoder == nil) then
    error("Attempted to send an unknown message type")
  end
  --encode the message
  local message = message_type_to_char[message_type] .. encoder(data)
  --send the message
  client_socket:send(message .. "\n")
end



--describes how to decode a message for each message type
local decode_message = {

  [messenger.MEMORY] = function(split_message)
    local memchanges = {}
    for i, mem in pairs(split_message) do
      local splitmem = bizstring.split(mem, ":")
      memchanges[tonumber(splitmem[0])] = tonumber(splitmem[1])
    end

    return memchanges
  end,

  [messenger.CONFIG] = function(split_message)
    --get sync hash from message
    local their_sync_hash = split_message[0]
    return {their_sync_hash}
  end,

  [messenger.QUIT] = function(split_message)
    return {}
  end
}

--recieves a message from the other client, returning the message type
--along with a table containing the message type-specific information
--if nonblocking not set then this will block until a message is received
--or timeouts. Otheriwse it will return nil if no message is receive.
function messenger.receive(client_socket, nonblocking)
  if nonblocking then
    client_socket:settimeout(0)
  end

  --get the next message
  local message, err = client_socket:receive()

  if nonblocking then
    client_socket:settimeout(config.input_timeout)
  end

  if(message == nil) then
    if err == "timeout" then
      if not nonblocking then 
        error("Timed out waiting for a message from the other player (the other player may have disconnected.)")
      else
        return nil
      end
    elseif err == "closed" then
      error("Other player closed the connection.")
    else
      error("Unexpected error.")
    end
  end

  --determine message type
  local message_type = char_to_message_type[message:sub(1,1)]
  if (message_type == nil) then
    error("Recieved an unidentifiable message.")
  end
  message = message:sub(2)
  --decode the message
  local decoder = decode_message[message_type]
  local split_message = bizstring.split(message, ",")
  local data = decoder(split_message)
  --return info
  return message_type, data
end


return messenger