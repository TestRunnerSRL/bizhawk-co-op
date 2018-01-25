#Metroid: Zero Mission - Co-op Netplay

mzm-co-op is a Lua script for BizHawk that allows two people to play a co-op experience by sharing inventory/ammo/hp over the network.

##Setup

###You will need the following:

* (1) [BizHawk 1.x.x](https://github.com/TASVideos/BizHawk/releases/tag/1.13.1) - Preferably after 1.12.0
* (2) [BizHawk prerequisite installer](http://sourceforge.net/projects/bizhawk/files/Prerequisites/bizhawk_prereqs_v1.1.zip/download) (run this)
* (3) [luasocket](http://files.luaforge.net/releases/luasocket/luasocket/luasocket-2.0.2/luasocket-2.0.2-lua-5.1.2-Win32-vc8.zip)
* (4) mzm-coop

###Directory structure

The locations of files is very important! Make sure to put them in the right place. After unzipping BizHawk (1), you should be able to find the executable `EmuHawk.exe`, we will call the folder containing it `BizHawkRoot/`.

First, in luasocket (3), you should find three folders, a file, and an executable: `lua/`, `mime/`, `socket/`, `lua5.1.dll`, and `lua5.1.exe`.
Place `mime/` and `socket/` in `BizHawkRoot/`, and place the *contents* of `lua/` in `BizHawkRoot/Lua/`. Place `lua5.1.dll` in `BizHawkRoot/dll/`. You do not need `lua5.1.exe`.

Next, the mzm-coop distribution includes two important things: the main lua script `mzm co-op.lua` and a folder `mzm_coop/`. Place both of these in `BizHawkRoot/`.

Once this is done, your directory structure should look like this:

```
(1) BizHawkRoot/ 
(4)   mzm_coop/
(1)   dll/
(3)     lua5.1.dll
        ...
(3)   mime/
        ...
(3)   socket/
        ...
(1)   Lua/
(3)     socket/
(3)     ltn12.lua
(3)     mime.lua
(3)     socket.lua

(4)   mzm co-op.lua
(1)   EmuHawk.exe
      ...
```

###mzm-coop Configuration

Once you have everything else properly set up, you can run the mzm-coop script to do some final setup before syncing and playing a game. To run the script in BizHawk, go to `Tools -> Lua Console`, and the Lua Console should open up. At this point, I suggest checking `Settings -> Disable Script on Load` and `Settings -> Autoload`. The former will allow you to choose when to start the script after opening it instead of it running automatically, and the latter will open the Lua Console automatically when you load EmuHawk.

Next, go to `Script -> Open Script...` and open `mzm co-op.lua` (it should be in `BizHawkRoot/`.) Make sure you are running a game, and then double click mzm-coop (or click it and then press the green check mark) to run the script. The window has the following important configurations:

* Host IP and Port: The client should set the IP to the host's IP address, and both players must choose the same port number. The host will have to have port forwarding enabled on this port, and will have to make sure their firewall is not blocking BizHawk. Google is your friend.

Make sure to click Save Settings, and you should be ready to play!


##Syncing with mzm-coop

After both players have the mzm-coop window up, the host clicks Host to host, and the client clicks Join to join. mzm-coop will run some consistency checks on your configurations to make sure. If these all pass and the two players will be synced.

* Close Connection: Click this to cleanly close down the connection. Closing the Lua Console or BizHawk directly can result in issues reconnecting for some time, and may cause the other player to hang.

###Supported Systems

mzm-coop will only run on a Windows os (BizHawk does not have recent versions for other operating systems anyway.)

###Credits

Created by TestRunner.

Credit to BizHawk, Lua, Luasocket, and kikito's sha1 script. Lua, luasocket, and sha1.lua all fall under the MIT license.

###Issues

If you have any problems with the script (and restarting BizHawk does not fix them,) contact me (TestRunner ([@Test_Runner](https://twitter.com/Test_Runner)) on Twitter. You can also submit an issue here on the GitHub.