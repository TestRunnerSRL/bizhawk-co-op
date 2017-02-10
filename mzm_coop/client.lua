--author: TheOnlyOne

local socket = require("socket")
local sync = require("mzm_coop\\sync")

return function()

	client_socket, err = socket.connect(config.hostname, config.port)
	if (client_socket == nil) then
		printOutput("Connection failed: " .. err)
		cleanConnection()
		return
	end

	--display the server's information
	local peername, peerport = client_socket:getpeername()
	printOutput("Connected to " .. peername .. " on port " .. peerport)
	coroutine.yield()
	coroutine.yield()


	--make sure we don't block waiting for a response
	client_socket:settimeout(config.input_timeout)

	--sync the gameplay
	sync.initialize() 
	sync.syncconfig(client_socket, 2)
	
	updateGUI()
	syncStatus = "Play"
	printOutput("Successful Sync")
	return
end