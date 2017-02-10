--author: TheOnlyOne

local socket = require("socket")
local sync = require("mzm_coop\\sync")

return function()
	--create the server
	local server = assert(socket.bind("*", config.port, 1))
	local ip, setport = server:getsockname()
	printOutput("Created server at " .. ip .. " on port " .. setport)

	--make sure we don't block waiting for a client_socket to accept
	server:settimeout(config.accept_timeout)
	--wait for the connection from the client
	printOutput("Awaiting connection.")
	coroutine.yield()
	coroutine.yield()
	local err
	client_socket, err = server:accept()

	--end execution if a client does not connect in time
	if (client_socket == nil) then
	  printOutput("Timed out waiting for client to connect.")
	  cleanConnection()
	  server:close()
	  return
	end

	--display the client's information
	local peername, peerport = client_socket:getpeername()
	printOutput("Connected to " .. peername .. " on port " .. peerport)
	coroutine.yield()
	coroutine.yield()

	-- make sure we don't block forever waiting for input
	client_socket:settimeout(config.input_timeout)

	--sync the gameplay
	sync.initialize() 
	sync.syncconfig(client_socket, 1)
	
	updateGUI()
	syncStatus = "Play"
	printOutput("Successful Sync")
	return 
end