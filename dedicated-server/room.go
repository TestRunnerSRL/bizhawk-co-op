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
	ConfigMessagePayload(id PlayerID) string
	Itemlist() string
	ValidateClientConfig(*Message) (PlayerID, error)
	ReleasePlayerID(PlayerID)
}

// A Room manages all of the connections and state for clients in a single
// co-op game.
type Room struct {
	syncConfig syncConfigInterface

	wg sync.WaitGroup

	mux sync.RWMutex
	// All active connections, keyed by user name.
	clients map[string]chan *Message // guarded by mux
}

// Creates a new room using the provided SyncConfig.
func NewRoom(syncConfig syncConfigInterface) *Room {
	r := &Room{
		syncConfig: syncConfig,
		clients:    make(map[string]chan *Message),
	}
	return r
}

// Takes ownership of a new connection, handling initial handshake,
// keep-alive pings, and handling/propagation of all received messages.
// This function takes responsibility for closing the connection.
func (r *Room) HandleConnection(conn io.ReadWriteCloser) {
	r.wg.Add(1)
	defer r.wg.Done()
	log.Printf("Player connecting...")
	defer conn.Close()

	// Verify the client's config.
	scanner := bufio.NewScanner(conn)
	channel := make(chan *Message, 10)
	userName, playerID, err := r.initializeConnection(scanner, conn, channel)
	if err != nil {
		log.Printf("Configuration consistency check failed: %v", err)
		return
	}
	log.Printf("%s connected", userName)
	defer func() {
		r.mux.Lock()
		delete(r.clients, userName)
		r.mux.Unlock()
		r.syncConfig.ReleasePlayerID(playerID)
	}()

	// Start a goroutine that forwards messages to the client.
	done := make(chan struct{})
	defer close(done)
	go func() {
		for {
			select {
			case msg := <-channel:
				if err := msg.Send(conn); err != nil {
					log.Printf("Failed to forward %s to %s: %v", msg, userName, err)
				}
				// If the server is quiting, close the connection.
				if msg.MessageType == QUIT_MESSAGE && msg.FromUserName == SERVER_USER_NAME {
					conn.Close()
				}
			case <-done:
				return
			}
		}
	}()

	// The client should get a ping every 10 seconds to keep the connection alive.
	// If the client misses 4 pings in a row, close the connection.
	ping := make(chan struct{}, 1)
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
		// Some control messages are handled here.
		switch msg.MessageType {
		case PING_MESSAGE:
			ping <- struct{}{}
		// TODO(bmclarnon): Add extra processing for RAM_EVENT_MESSAGEs so we
		// can display what items have been collected.
		default:
			r.mux.RLock()
			for userName, channel := range r.clients {
				if msg.FromUserName != userName {
					channel <- msg
				}
			}
			r.mux.RUnlock()
		}
	}
	log.Printf("%s disconnected", userName)
}

// Disconnects all clients.
func (r *Room) Close() error {
	// Send a QUIT_MESSAGE to all connected clients.
	msg := &Message{
		MessageType:  QUIT_MESSAGE,
		FromUserName: SERVER_USER_NAME,
	}
	r.mux.RLock()
	for _, channel := range r.clients {
		channel <- msg
	}
	r.mux.RUnlock()
	// Wait for all connections to be closed.
	r.wg.Wait()
	return nil
}

// Performs initial configuration, including syncing configs with the client.
func (r *Room) initializeConnection(scanner *bufio.Scanner, conn io.ReadWriteCloser, channel chan *Message) (string, PlayerID, error) {
	if !scanner.Scan() {
		if err := scanner.Err(); err != nil {
			return "", 0, err
		}
		return "", 0, ErrConnectionClosed
	}

	// The first thing the client sends should be its config.
	msg, err := DecodeMessage(scanner.Text())
	if err != nil {
		return "", 0, err
	}
	playerID, err := r.syncConfig.ValidateClientConfig(msg)
	if err != nil {
		return "", 0, err
	}

	// Clients should immediately receive their configuration.
	configMsg := Message{
		MessageType:  CONFIG_MESSAGE,
		FromUserName: SERVER_USER_NAME,
		Payload:      r.syncConfig.ConfigMessagePayload(playerID),
	}
	if err := configMsg.Send(conn); err != nil {
		r.syncConfig.ReleasePlayerID(playerID)
		return "", 0, fmt.Errorf("error sending config: %w", err)
	}

	r.mux.Lock()
	defer r.mux.Unlock()
	if _, ok := r.clients[msg.FromUserName]; ok {
		r.syncConfig.ReleasePlayerID(playerID)
		return "", 0, fmt.Errorf("%w, name=%s", ErrSyncUserNameInUse, msg.FromUserName)
	}
	r.clients[msg.FromUserName] = channel

	return msg.FromUserName, playerID, nil
}

// Sends the item list to all clients.
func (r *Room) sendItemList() {
	itemlist := &Message{
		MessageType:  RAM_EVENT_MESSAGE,
		FromUserName: SERVER_USER_NAME,
		Payload:      r.syncConfig.Itemlist(),
	}
	r.mux.RLock()
	for _, channel := range r.clients {
		channel <- itemlist
	}
	r.mux.RUnlock()
}
