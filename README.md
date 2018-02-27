# Bizhawk Co-op Netplay

bizhawk-co-op is a Lua script for BizHawk that allows two or more people to play a co-op experience by sharing inventory/ammo/hp over the network. This will work with vanilla versions of the games and also randomizers.

## Metroid: Zero Mission Co-op

Health and ammo is shared. Items obtained by a player are given to everyone. Items locations are split such that each item can be optained by only one player. The other players will find a screw attack block in its place. The items at the unknown item locations, power grip location, and imago location can be obtained by either player. Events such as boss deaths are also shared.

## Link to the Past Co-op

Items obtained by a player are given to everyone. Items locations are split such that each item can be optained by only one player. It's usually a good idea to spread out on the overworld and communicate which items still need to be checked by who. With Split Keys or Raid Bosses enabled, it's highly recommended to enter dungeons together. The following can are configurable:
 
* **Health and Ammo** Health and ammo is shared. This includes bottles, bombs, arrows, magic, etc. Death is synced, so if you notice a pause, it's because the script is waiting for everyone to die together
* **Split Big Keys** If enabled then dungeon Big Keys will be split so only one person can obtain it. Otherwise either player can get them.
* **Split Small Keys** Similar to Big Keys, but is for the dungeon Small Keys. This includes Pot Keys and Enemy Drop Keys. Using a key does not remove other players keys. When disabled keys are not shared.
* **Raid Bosses** Bosses share HP. Bosses have scaled HP based on the number players. Players get a damage boost if they attack the boss together at the same time. If everyone is fighting together, then the boss should have similar amount of health as solo. A known bug is that boss that can normally be killed in one hit still die in one hit, so bring your silver arrows with you. You can also have someone stay behind and be the dedicated healer at the cost of dps.

| Players | Boss HP |
|---|-------|
| 1 | 1x    |
| 2 | 3.5x  |
| 3 | 9.5x  |
| 4 | 23.5x |
| 5 | 55.5x |
| ... | ... |

* **Junk Chests** If enabled then item locations not owned by players are filled with random junk items. Having this enabled will make it harder to coordinate who still needs to chest some item location. When disabled they are instead replaced with empty chests. If you find an empty location it means that someone else owns that item location and should check it still.

## Setup

There are two methods to install. 
1) Run the PowerShell script. Download, right-click and select "Run with PowerShell". [mzm-co-op.ps1](https://raw.githubusercontent.com/TestRunnerSRL/bizhawk-co-op/master/bizhawk-co-op.ps1)
2) Download the files and move them in the correct locations as described below.

### You will need the following:

* (1) [BizHawk 1.12.0](https://github.com/TASVideos/BizHawk/releases/tag/1.12.0)
* (2) [BizHawk prerequisite installer](https://github.com/TASVideos/BizHawk-Prereqs/releases/tag/1.4) (run this)
* (3) [luasocket](http://files.luaforge.net/releases/luasocket/luasocket/luasocket-2.0.2/luasocket-2.0.2-lua-5.1.2-Win32-vc8.zip)
* (4) [bizhawk-co-op](https://github.com/TestRunnerSRL/bizhawk-co-op/archive/master.zip)

### Directory structure

The locations of files is very important! Make sure to put them in the right place. After unzipping BizHawk (1), you should be able to find the executable `EmuHawk.exe`, we will call the folder containing it `BizHawkRoot/`.

First, in luasocket (3), you should find three folders, a file, and an executable: `lua/`, `mime/`, `socket/`, `lua5.1.dll`, and `lua5.1.exe`.
Place `mime/` and `socket/` in `BizHawkRoot/`, and place the *contents* of `lua/` in `BizHawkRoot/Lua/`. Place `lua5.1.dll` in `BizHawkRoot/dll/`. You do not need `lua5.1.exe`.

Next, the mzm-coop distribution includes two important things: the main lua script `mzm co-op.lua` and a folder `mzm_coop/`. Place both of these in `BizHawkRoot/`.

Once this is done, your directory structure should look like this:

```
(1) BizHawk-1.12.0/ 
(4)   bizhawk-co-op/
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

(4)   bizhawk co-op.lua
(1)   EmuHawk.exe
      ...
```

### bizhawk-co-op Configuration

Once you have everything else properly set up, you can run the mzm-coop script to do some final setup before syncing and playing a game. To run the script in BizHawk, go to `Tools -> Lua Console`, and the Lua Console should open up. At this point, I suggest checking `Settings -> Disable Script on Load` and `Settings -> Autoload`. The former will allow you to choose when to start the script after opening it instead of it running automatically, and the latter will open the Lua Console automatically when you load EmuHawk.

Next, go to `Script -> Open Script...` and open `bizhawk co-op.lua` (it should be in `BizHawk-1.12.0/` root.) Make sure you are running a game, and then double click mzm-coop (or click it and then press the green check mark) to run the script. The window has the following important configurations:

* Host IP and Port: The client should set the IP to the host's IP address, and both players must choose the same port number. The host will have to have port forwarding enabled on this port, and will have to make sure their firewall is not blocking BizHawk. Google is your friend.

Make sure to click Save Settings, and you should be ready to play!


## Syncing with bizhawk-coop

The host should first enter their name and password and click `Create Room` to host. Then the clients should click `Refresh` and select the appropriate room, enter their name and the room password, and click `Join Room`. bizhawk-co-op will run some consistency checks on your configurations to make sure you are running the same code. If these all passes then the players will be connected.

* `Lock Room`: The Host can click this to prevent prevent anyone else from joining the room. 
* `Leave Room`: Click this to cleanly close down the connection. Closing the Lua Console or BizHawk directly can result in issues reconnecting for some time.


### Supported Systems

bizhawk-co-op will only run on a Windows OS because of BizHawk support.

### Credits

Created by TestRunner.

BizHawk, Lua, Luasocket, and kikito's sha1 script. Lua, luasocket, and sha1.lua all fall under the MIT license.

### Issues

If you have any problems with the script (and restarting BizHawk does not fix them,) contact me (TestRunner ([@Test_Runner](https://twitter.com/Test_Runner)) on Twitter or on Discord. You can also submit an issue here on the GitHub.