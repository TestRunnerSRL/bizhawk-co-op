package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"
)

const USAGE = `USAGE: dedicated_server [FLAGS]

Runs a BizHawk co-op server compatible with the in-emulator
Lua scrips. Running a dedicated server has better performance
with a large number of clients, and ensures that the co-op
game is not dependent on the host's BizHawk process. If
necessary, the dedicated server can be run on a completely
different server (e.g., AWS EC2 or GCP).

`

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, USAGE)
		flag.PrintDefaults()
	}
	var port = flag.Int("port", 50000, "TCP/IP port on which the server runs")
	//var upnpPort = flag.Int("upnpport", 0, "External port to enable via UPnP, or 0 to disable UPnP")
	var syncHash = flag.String("synchash", "", "Configuration hash to ensure consistent versions.")
	var ramConfig = flag.String("ramconfig", "", "Game-specific configuration string.")
	flag.Parse()

	// TODO(bmclarnon): Use UPnP to automatically set up port forwarding with
	// compatible routers.
	// TODO(bmclarnon): Add a flag-controlled admin interface to kick players
	// from a room and see what items each player has collected.
	// TODO(bmclarnon): Generate the supported built-in hashes (and ramconfigs)
	// as part of the build process using go generate and go run.

	// Create the server, which should be closed on shutdown.
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", *port))
	if err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
	defer func() {
		if err := listener.Close(); err != nil {
			log.Printf("Server shutdown failed: %v", err)
		}
	}()

	// Create the room, which should be closed on shutdown.
	room := NewRoom(*syncHash, *ramConfig)
	defer func() {
		if err := room.Close(); err != nil {
			log.Printf("Failed to disconnect users: %v", err)
		}
	}()

	// Run until the listener is closed due to the listener being closed.
	log.Printf("Running on localhost:%d", *port)
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				// An error usually indicates the listener was closed.
				break
			}
			go room.HandleConnection(conn)
		}
	}()

	// Wait until SIGINT and SIGTERM is received.
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
	<-sigs
	log.Printf("Shutting down...")
}
