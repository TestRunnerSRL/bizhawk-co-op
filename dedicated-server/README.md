# Dedicated Server

`dedicated-server` is a stand-alone server fully compatible with the
bizhawk-co-op Lua script. Running the server in a separate process reduces the
load on BizHawk and leads to more stable games for tens or hundreds of players.

## Building

Download [go](https://golang.org/dl/) and run `go build` in this directory.

## Running

Use the following command to run the dedicated server:

```
./dedicated-server --upnpport=50000 --room=<NAME> --pass=<PASS>
```

The server will run on local port `--port` (default 50000) and set up port
forwarding from external port `--upnpport`. As a convenience, the external IP
address will be printed once the server is running. A management tool is also
started at http://localhost:8080/ that supports kicking players. Use Ctrl-C to
stop the server; all players will be disconnected and the room will be
automatically unregistered.

If you have multiple routers or if your router doesn't support UPnP port
forwarding, the `--upnpport` option may fail. In that case, port forwarding
must be set up manually.

See `--help` for additional usage options.

## Games Other Than OoT

When using the dedicated server with games other than OoT, use the `--ramconfig`
and `--itemcount` flags to configure the game-specific ramcontroller settings.
Unfortunately, there isn't currently a convenient way to determine the right
values without reading the ramcontroller's code.

## Developing

Unit tests can be run using `go test`. Ramcontroller sha1 hashes can be
regenerated using `go generate`.

Before submitting new changes, please verify that `go vet` and
[golint](https://github.com/golang/lint) do not find any issues.
