--author: TheOnlyOne

local socket = require("socket")
local sync = require("mzm_coop\\sync")

local host = {}

local server = nil
host.clients = {}

function host.start()
	--create the server
	server = socket.bind("*", config.port, 1)
	if (server == nil) then
		printOutput("Error creating server.")
		return false
	end

	local ip, setport = server:getsockname()
	server:settimeout(0) -- non-blocking
	printOutput("Created server at " .. ip .. " on port " .. setport)

	return true
end


function host.listen()
	if (server == nil) then
		return false
	end

	--wait for the connection from the client
	local client, err = server:accept()

	--end execution if a client does not connect in time
	if (client == nil) then
		if err ~= "timeout" then
            printOutput("Server error: ", err)
	  		host.close()
        end
	  	return false
	end

	local clientID = 2
	while (true) do
	 	if (host.clients[clientID] == nil) then
	 		break
	 	end
		clientID = clientID + 1
	end

	--display the client's information
	local peername, peerport = client:getpeername()
	printOutput("Player " .. clientID .. " connected from " .. peername .. " on port " .. peerport)
	
	-- make sure we don't block forever waiting for input
	client:settimeout(config.input_timeout)

	--sync the gameplay
	if sync.syncconfig(client, clientID) then
		host.clients[clientID] = client
	else 
		client:close()
		return false
	end

	-- send item lists
	local clientMap = {[0]=1}
	local clientCount = 1
	for id,_ in pairs(host.clients) do
		clientMap[clientCount] = id
		clientCount = clientCount + 1
	end

	local itemlist = {}
	math.randomseed(os.time())
	for i=0,99 do
		itemlist[i] = clientMap[i % clientCount]
	end

	for i=1,99 do
		j = math.random(i)
		itemlist[i], itemlist[j] = itemlist[j], itemlist[i]
	end

	sync.sendItems(itemlist)

	updateGUI()
	return clientID
end


function host.join()
	host.close()

	coroutine.yield()

	local client, err = socket.connect(config.hostname, config.port)
	if (client == nil) then
		printOutput("Connection failed: " .. err)
		return
	end

	--display the server's information
	local peername, peerport = client:getpeername()
	printOutput("Connected to " .. peername .. " on port " .. peerport)

	--make sure we don't block waiting for a response
	client:settimeout(config.input_timeout)

	coroutine.yield()
	coroutine.yield()

	--sync the gameplay
	if (sync.syncconfig(client, nil)) then	
		host.clients[1] = client
	else
		client:close()
	end
	updateGUI()

	return
end


--when the script finishes, make sure to close the connection
function host.close()
	local changed = false

	for i,client in pairs(host.clients) do
		client:close()
		host.clients[i] = nil
		changed = true
	end

	if (server ~= nil) then
		server:close()
		changed = true
	end
	server = nil

	if changed then
		printOutput("Server closed.")
		updateGUI()
	end
end


function host.connected()
    for _, _ in pairs(host.clients) do
        return true
    end
    return false
end


function host.ishost()
	return ((host.connected()) and (host.server ~= nil))
end


return host