local guiClick = {}

form1 = nil
local text1, btnQuit, btnClient
local txbIP, lblIP, txbPort, lblPort
config = {}


--Reloads the config file, overwriting any changes made
function loadConfig()
	config = dofile("mzm_coop\\config")

	updateGUI()
end


--Saves the config file.
--dontRead flag will prevent reading changes made in the form
function saveConfig(dontRead)
	if (dontRead == nil) then
		config.hostname = forms.gettext(txbIP)
		config.port = tonumber(forms.gettext(txbPort))
	end

	local output = [[
local config = {}

--This is the port the connection will happen over. Make sure this is the same
--for both players before trying to sync.
config.port = ]] .. config.port .. [[

--This is the ip address or hostname of the player running host.lua (ip
--addresses should should still be in quotes.) This value is only inportant
--for the client.
config.hostname = "]] .. config.hostname .. [["

return config
]]

	f = assert(io.open("mzm_coop\\config", "w"))
	f:write(output)
	f:close()
end


--Attempt to load config file
require_status, config = pcall(function()
	return dofile("mzm_coop\\config")
end)
--If config file not found, then create a default config file
if not require_status then
	config = {}
	config.port = 54321
	config.hostname = "localhost"

	saveConfig(true)
end


local sync = require("mzm_coop\\sync")


--stringList contains the output text
local stringList = {last = 1, first = 24}
for i = stringList.first, stringList.last, -1 do
	stringList[i] = ""
end


--add a new line to the string list
function stringList.push(value)
  stringList.first = stringList.first + 1
  stringList[stringList.first] = value
  stringList[stringList.last] = nil
  stringList.last = stringList.last + 1
end


--get the entire string list as a single string
function stringList.tostring()
	local outputstr = ""
	for i = stringList.first, stringList.last, -1 do
		outputstr = outputstr .. stringList[i] .. "\r\n"
	end

	return outputstr
end


--Add a line to the output. Inserts a timestamp to the string
function printOutput(str) 
	str = string.gsub (str, "\n", "\r\n")
	str = "[" .. os.date("%H:%M:%S", os.time()) .. "] " .. str
	stringList.push(str)

	forms.settext(text1, stringList.tostring())
end


host = require("mzm_coop\\host")


--Reloads all the info on the form. Disables any inappropriate components
function updateGUI()
	forms.settext(txbIP, config.hostname)
	forms.settext(txbPort, config.port)

	if host.connected() then
		forms.setproperty(txbIP, "Enabled", false)
		forms.setproperty(txbPort, "Enabled", false)
		forms.setproperty(btnClient, "Enabled", false)
		forms.setproperty(btnLoadConfig, "Enabled", false)
		forms.settext(btnQuit, "Close Connection")	
	else
		forms.setproperty(txbIP, "Enabled", true)
		forms.setproperty(txbPort, "Enabled", true)
		forms.setproperty(btnClient, "Enabled", true)
		forms.setproperty(btnLoadConfig, "Enabled", true)
		forms.settext(btnQuit, "Quit")	
	end
end


--If the script ends, makes sure the sockets and form are closed
event.onexit(function () host.close(); forms.destroy(form1) end)


--furthermore, override error with a function that closes the connection
--before the error is actually thrown
local old_error = error

error = function(str, level)
  host.close()
  old_error(str, 0)
end


--Load the changes from the form and disable any appropriate components
function prepareConnection()
	config.hostname = forms.gettext(txbIP)
	config.port = tonumber(forms.gettext(txbPort))
	
	forms.setproperty(txbIP, "Enabled", false)
	forms.setproperty(txbPort, "Enabled", false)
	forms.setproperty(btnClient, "Enabled", false)
end


--Quit/Disconnect click handle for the quit button
function quit2P1C()
	if (host.connected()) then
		sendMessage["Quit"] = true
	else
		forms.destroy(form1)
	end
end


--Returns a list of files in a given directory
function os.dir(dir)
	local f = assert(io.popen("dir " .. dir, 'r'))
	local s = f:read('*all')
	f:close()

	local matched = string.gmatch(s, "%s(%w+)%.%w+\n")

	local files = {}
	for file,k in matched do table.insert(files, tostring(file)) end
	return files
end


--Create the form
form1 = forms.newform(580, 390, "Metroid: Zero Mission: Co-op")
forms.setproperty(form1, "ControlBox", false)

text1 = forms.textbox(form1, "", 260, 325, nil, 290, 10, true, false)
forms.setproperty(text1, "ReadOnly", true)

btnQuit = forms.button(form1, "Quit 2P1C", quit2P1C, 145, 10, 125, 30)

btnClient = forms.button(form1, "Join", function() prepareConnection(); guiClick["Join Server"] = host.join end, 190, 50, 80, 30)

txbIP = forms.textbox(form1, "", 140, 20, nil, 10, 110, false, false)
lblIP = forms.label(form1, "Host IP (Client only):", 15, 95, 120, 20)
txbPort = forms.textbox(form1, "", 60, 20, "UNSIGNED", 160, 110, false, false)
lblPort = forms.label(form1, "Port:", 165, 95, 50, 20)

btnSaveConfig = forms.button(form1, "Save Settings", function() guiClick["Save Settings"] = saveConfig end, 10, 310, 125, 25)
btnLoadConfig = forms.button(form1, "Discard Changes", function() guiClick["Discard Changes"] = loadConfig end, 145, 310, 125, 25)


sendMessage = {}
local thread

updateGUI()

local threads = {}


host.start()


---------------------
--    Main loop    --
---------------------
while 1 do
	--End script if form is closed
	if forms.gettext(form1) == "" then
		return
	end

	host.listen()

	--Create threads for the function requests from the form
	for k,v in pairs(guiClick) do
		threads[coroutine.create(v)] = k
	end
	guiClick = {}

	--Run the threads
	for k,v in pairs(threads) do
		if coroutine.status(k) == "dead" then
			threads[k] = nil
		else
			local status, err = coroutine.resume(k)
			if (status == false) then
				if (err ~= nil) then
					printOutput("Error during " .. v .. ": " .. err)
				else
					printOutput("Error during " .. v .. ": No error message")
				end
			end						
		end
	end

	--If connected, run the syncinputs thread
	if host.connected() then
		--If the thread didn't yield, then create a new one
		if thread == nil or coroutine.status(thread) == "dead" then
			thread = coroutine.create(sync.syncRAM)
		end
		local status, err = coroutine.resume(thread, host.clients)

		if (status == false and err ~= nil) then
			printOutput("Error during sync inputs: " .. tostring(err))
		end
	end

	-- 2 Emu Yields = 1 Frame Advance
	--If game is paused, then yield will not frame advance
	emu.yield()
	emu.yield()
end