package main

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"log"
	"sync"
	"time"
)

// The user name reported by the server. This must be unique.
const SERVER_USER_NAME = "Server"

var (
	ErrConnectionClosed  = errors.New("connection closed unexpectedly")
	ErrSyncUserNameInUse = errors.New("user name already in use")
)

// Satisfied by SyncConfig. Allows dependency injection for testing.
type syncConfigInterface interface {
	ConfigMessagePayload() string
	Itemlist() string
	ValidateClientConfig(*Message) error
}

// A Room manages all of the connections and state for clients in a single
// co-op game.
type Room struct {
	syncConfig syncConfigInterface

	// All received messages for the room are written to this channel.
	msgChannel chan *Message
	// Triggered when the room should shut down.
	done chan bool

	mux sync.Mutex
	// All active connections, keyed by user name.
	clients map[string]io.ReadWriteCloser // guarded by mux
}

// Creates a new room using the provided SyncConfig.
func NewRoom(syncConfig syncConfigInterface) *Room {
	r := &Room{
		syncConfig: syncConfig,
		msgChannel: make(chan *Message, 10),
		done:       make(chan bool, 1),
		mux:        sync.Mutex{},
		clients:    make(map[string]io.ReadWriteCloser),
	}
	go r.handleMessages()
	return r
}

// Takes ownership of a new connection, handling initial handshake,
// keep-alive pings, and handling/propagation of all received messages.
// This function takes responsibility for closing the connection.
func (r *Room) HandleConnection(conn io.ReadWriteCloser) {
	log.Printf("Player connecting...")
	defer conn.Close()

	// Verify the client's config.
	scanner := bufio.NewScanner(conn)
	userName, err := r.initializeConnection(scanner, conn)
	if err != nil {
		log.Printf("Configuration consistency check failed: %v", err)
		return
	}
	log.Printf("%s connected", userName)
	defer func() {
		r.mux.Lock()
		delete(r.clients, userName)
		r.mux.Unlock()
	}()

	// The client should get a ping every 10 seconds to keep the connection alive.
	// If the client misses 4 pings in a row, close the connection.
	ping := make(chan bool, 1)
	done := make(chan bool, 1)
	defer func() { done <- true }()
	go func() {
		ticker := time.NewTicker(10 * time.Second)
		defer ticker.Stop()
		missedPings := 0
		for missedPings < 4 {
			select {
			case <-ticker.C:
				missedPings += 1
				msg := Message{
					MessageType:  PING_MESSAGE,
					FromUserName: SERVER_USER_NAME,
				}
				if err := msg.Send(conn); err != nil {
					log.Printf("Ping failed to %s: %v", userName, err)
				}
			case <-ping:
				missedPings = 0
			case <-done:
				return
			}
		}
		log.Printf("%s timed out", userName)
		// Close the connection so that the `for scanner.Scan()` loop below
		// exits immediately.
		conn.Close()
	}()

	// Send the item list to all clients whenever a new client connects.
	r.sendItemList()

	for scanner.Scan() {
		msg, err := DecodeMessage(scanner.Text())
		if err != nil {
			log.Printf("Failed to decode message from %s (%s): %v", userName, scanner.Text(), err)
			continue
		}
		r.msgChannel <- msg
		// There is additional handling for some control messages.
		switch msg.MessageType {
		case PING_MESSAGE:
			ping <- true
		}
	}
	if err := scanner.Err(); err != nil {
		log.Printf("%s disconnected with error: %v", userName, err)
	} else {
		log.Printf("%s disconnected", userName)
	}
}

// Disconnects all clients.
func (r *Room) Close() error {
	// Send a QUIT_MESSAGE to all connected clients.
	msg := Message{
		MessageType:  QUIT_MESSAGE,
		FromUserName: SERVER_USER_NAME,
	}
	r.mux.Lock()
	for userName, conn := range r.clients {
		log.Printf("Closing %s", userName)
		if err := msg.Send(conn); err != nil {
			log.Printf("Failed to send quit to %s: %v", userName, err)
		}
		if err := conn.Close(); err != nil {
			log.Printf("Failed to close connection to %s: %v", userName, err)
		}
	}
	r.mux.Unlock()
	r.done <- true
	return nil
}

// Performs initial configuration, including syncing configs with the client.
func (r *Room) initializeConnection(scanner *bufio.Scanner, conn io.ReadWriteCloser) (string, error) {
	// Clients should immediately receive their configuration.
	configMsg := Message{
		MessageType:  CONFIG_MESSAGE,
		FromUserName: SERVER_USER_NAME,
		Payload:      r.syncConfig.ConfigMessagePayload(),
	}
	if err := configMsg.Send(conn); err != nil {
		return "", fmt.Errorf("error sending config: %w", err)
	}

	if !scanner.Scan() {
		if err := scanner.Err(); err != nil {
			return "", err
		}
		return "", ErrConnectionClosed
	}

	// The first thing the client sends should be its config.
	msg, err := DecodeMessage(scanner.Text())
	if err != nil {
		return "", err
	}
	if err := r.syncConfig.ValidateClientConfig(msg); err != nil {
		return "", err
	}

	r.mux.Lock()
	defer r.mux.Unlock()
	if _, ok := r.clients[msg.FromUserName]; ok {
		return "", fmt.Errorf("%w, name=%s", ErrSyncUserNameInUse, msg.FromUserName)
	}
	r.clients[msg.FromUserName] = conn

	return msg.FromUserName, nil
}

// Sends the item list to all clients. This currently only supports OOT.
func (r *Room) sendItemList() {
	itemlist := Message{
		MessageType:  RAM_EVENT_MESSAGE,
		FromUserName: SERVER_USER_NAME,
		Payload:      r.syncConfig.Itemlist(),
	}
	r.mux.Lock()
	for userName, conn := range r.clients {
		if err := itemlist.Send(conn); err != nil {
			log.Printf("Failed to send itemlist to %s: %v", userName, err)
		}
	}
	r.mux.Unlock()
}

// Reads messages from the message channel until the room is closed.
func (r *Room) handleMessages() {
	for {
		select {
		case msg := <-r.msgChannel:
			if err := r.handleMessage(msg); err != nil {
				log.Printf("Failed to handle %s: %v", msg, err)
			}
		case <-r.done:
			break
		}
	}
}

// Handles a client message by forwarding it to all other clients.
func (r *Room) handleMessage(msg *Message) error {
	// Forward the message to all other clients.
	r.mux.Lock()
	for userName, conn := range r.clients {
		if userName == msg.FromUserName {
			continue
		}
		if err := msg.Send(conn); err != nil {
			log.Printf("Failed to forward %s to %s: %v", msg, userName, err)
		}
	}
	r.mux.Unlock()

	// TODO(bmclarnon): Add extra processing for RAM_EVENT_MESSAGEs so we can
	// display what items have been collected.
	return nil
}
