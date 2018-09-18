local guiClick = {}

mainform = nil
local text1, lblRooms, btnGetRooms, ddRooms, btnQuit, btnJoin, btnHost
local txtUser, txtPass, lblUser, lblPass, ddRamCode, lblRamCode
local lblPort, txtPort
config = {}


function strsplit(inputstr, sep, max)
  if not inputstr then
    return {}
  end

  if not sep then
    sep = ","
  end
  local t={} ; i=1
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    if max and i > max then
      t[i] = (t[i] or '') .. sep .. str
    else
      t[i] = str
      i = i + 1
    end
  end
  return t
end


local sync = require("bizhawk-co-op\\sync")


--Add a line to the output. Inserts a timestamp to the string
function printOutput(str) 
	local text = forms.gettext(text1)
	local pos = #text
	forms.setproperty(text1, "SelectionStart", pos)

	str = string.gsub (str, "\n", "\r\n")
	str = "[" .. os.date("%H:%M:%S", os.time()) .. "] " .. str
	if pos > 0 then
		str = "\r\n" .. str
	end

	forms.setproperty(text1, "SelectedText", str)
end


host = require("bizhawk-co-op\\host")


local roomlist = false
function refreshRooms() 
	roomlist = host.getRooms()
	if roomlist then
		roomlist['(Custom IP)']='(Custom IP)'
		forms.setdropdownitems(ddRooms, roomlist)
	else 
		forms.setdropdownitems(ddRooms, 
			{
				['(Custom IP)']='(Custom IP)'			
			})
	end

	updateGUI()
end


--Reloads all the info on the form. Disables any inappropriate components
function updateGUI()
	if host.status == 'Idle' then
		if forms.setdropdownitems and roomlist then
			forms.setproperty(ddRooms, 'Enabled', true)
		else 
			forms.setproperty(ddRooms, 'Enabled', false)
		end
		forms.setproperty(btnGetRooms, "Enabled", true)
		forms.setproperty(ddRamCode, "Enabled", true)
		forms.setproperty(txtUser, "Enabled", true)
		forms.setproperty(txtPass, "Enabled", true)
		forms.setproperty(txtPort, "Enabled", true)
		forms.setproperty(btnQuit, "Enabled", false)
		forms.setproperty(btnJoin, "Enabled", true)
		forms.setproperty(btnHost, "Enabled", true)
		forms.settext(btnHost, "Create Room")

		if forms.gettext(ddRooms) == '(Custom IP)' then
			forms.setproperty(txtIP, "Enabled", true)
		else
			forms.setproperty(txtIP, "Enabled", false)
		end
	else 
		forms.setproperty(btnGetRooms, "Enabled", false)
		forms.setproperty(ddRamCode, "Enabled", false)
		forms.setproperty(ddRooms, "Enabled", false)
		forms.setproperty(txtUser, "Enabled", false)
		forms.setproperty(txtPass, "Enabled", false)
		forms.setproperty(txtPort, "Enabled", false)
		forms.setproperty(btnQuit, "Enabled", true)
		forms.setproperty(btnJoin, "Enabled", false)
		forms.setproperty(btnHost, "Enabled", not host.locked)
		forms.settext(btnHost, "Lock Room")
		forms.setproperty(txtIP, "Enabled", false)
	end
end


--If the script ends, makes sure the sockets and form are closed
event.onexit(function () host.close(); forms.destroy(mainform) end)


--furthermore, override error with a function that closes the connection
--before the error is actually thrown
local old_error = error

error = function(str, level)
  host.close()
  old_error(str, 0)
end


--Load the changes from the form and disable any appropriate components
function prepareConnection()
	if roomlist then
		config.room = forms.gettext(ddRooms)
	else 
		config.room = ''
	end
	config.ramcode = forms.gettext(ddRamCode)
	config.user = forms.gettext(txtUser)
	config.pass = forms.gettext(txtPass)
	config.port = forms.gettext(txtPort)
	config.hostname = forms.gettext(txtIP)
end


--Quit/Disconnect click handle for the quit button
function leaveRoom()
	if (host.connected()) then
		sendMessage["Quit"] = true
	else 
		host.close()
	end
end


--Returns a list of files in a given directory
function os.dir(dir)
	local files = {}
	local f = assert(io.popen('dir \"' .. dir .. '\" /b ', 'r'))
	for file in f:lines() do
		table.insert(files, file)
	end
	f:close()
	return files
end


--Create the form
mainform = forms.newform(310, 356, "Bizhawk Co-op")

text1 = forms.textbox(mainform, "", 263, 105, nil, 16, 199, true, true, 'Vertical')
forms.setproperty(text1, "ReadOnly", true)
--forms.setproperty(text1, "MaxLength", 32767)


if forms.setdropdownitems then -- can't update list prior to bizhawk 1.12.0
	btnGetRooms = forms.button(mainform, "Refresh Rooms", refreshRooms, 220, 10, 60, 23)
	ddRooms = forms.dropdown(mainform, {['(Fetching rooms...)']='(Fetching rooms...)'}, 80, 11, 135, 20)
	forms.setproperty(ddRooms, 'Enabled', false)
	guiClick["Refresh Rooms"] = refreshRooms;
else
	btnGetRooms = forms.button(mainform, "", function() end, 15, 10, 60, 23)
	forms.setproperty(btnGetRooms, 'Enabled', false)

	roomlist = host.getRooms()
	if roomlist then
		ddRooms = forms.dropdown(mainform, roomlist, 80, 11, 200, 20)
		forms.setproperty(ddRooms, 'Enabled', true)
	else 
		ddRooms = forms.dropdown(mainform, {['(Custom IP)']='(Custom IP)'}, 80, 11, 200, 20)
		forms.setproperty(ddRooms, 'Enabled', false)
	end
end
lblRooms = forms.label(mainform, "Rooms:", 34, 13)

txtIP = forms.textbox(mainform, "", 200, 20, nil, 80, 40, false, false)
txtUser = forms.textbox(mainform, "", 200, 20, nil, 80, 64, false, false)
txtPass = forms.textbox(mainform, "", 200, 20, nil, 80, 88, false, false)
txtPort = forms.textbox(mainform, '50000', 200, 20, nil, 80, 112, false, false)
ddRamCode = forms.dropdown(mainform, os.dir("bizhawk-co-op\\ramcontroller"), 80, 138, 200, 10)
lblIP = forms.label(mainform, "Host IP:", 32, 42)
lblUser = forms.label(mainform, "Username:", 19, 66)
lblPass = forms.label(mainform, "Password:", 21, 90)
lblPort = forms.label(mainform, "Port:", 48, 115)
lblRamCode = forms.label(mainform, "Game Script:", 10, 140)

forms.setproperty(txtPass, 'UseSystemPasswordChar', true)


btnQuit = forms.button(mainform, "Leave Room", leaveRoom, 
	15, 166, 85, 25)
forms.setproperty(btnQuit, 'Enabled', false)
btnHost = forms.button(mainform, "Create Room", 
	function() prepareConnection(); guiClick["Host Server"] = host.start end, 
	105, 166, 85, 25)
btnJoin = forms.button(mainform, "Join Room", 
	function() prepareConnection(); guiClick["Join Server"] = host.join end, 
	195, 166, 85, 25)

sendMessage = {}
local thread

updateGUI()

local threads = {}

emu.yield()
emu.yield()

---------------------
--    Main loop    --
---------------------
while 1 do
	--End script if form is closed
	if forms.gettext(mainform) == "" then
		return
	end

	if (forms.gettext(ddRooms) ~= prevRoom) then
		prevRoom = forms.gettext(ddRooms)
		updateGUI()
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
			printOutput("Error during sync: " .. tostring(err))
		end
	end

	-- 2 Emu Yields = 1 Frame Advance
	--If game is paused, then yield will not frame advance
	emu.yield()
	emu.yield()
end