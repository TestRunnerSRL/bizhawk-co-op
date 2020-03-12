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
	ErrUnknownUser       = errors.New("unknown user")
)

// Satisfied by SyncConfig. Allows dependency injection for testing.
type syncConfigInterface interface {
	ConfigMessagePayload(id PlayerID) string
	Itemlist() string
	ValidateClientConfig(*Message) (PlayerID, error)
	ReleasePlayerID(PlayerID)
}

// Satisfied by PlayerList. Allows dependency injection for testing.
type playerListInterface interface {
	UpdateStatus(*Message)
	ValidatePlayerNumber(*Message) (PlayerNum, error)
	ReleasePlayerNum(PlayerNum)
	Subscribe(chan string)
	Unsubscribe(chan string)
}

// A Room manages all of the connections and state for clients in a single
// co-op game.
type Room struct {
	syncConfig syncConfigInterface
	playerList playerListInterface

	wg sync.WaitGroup

	mux sync.RWMutex
	// All active connections, keyed by user name.
	clients map[string]chan *Message // guarded by mux
}

// Creates a new room using the provided SyncConfig.
func NewRoom(syncConfig syncConfigInterface, playerList playerListInterface) *Room {
	r := &Room{
		syncConfig: syncConfig,
		playerList: playerList,
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
	userName, playerID, playerNum, err := r.initializeConnection(scanner, conn, channel)
	if err != nil {
		log.Printf("Configuration consistency check failed: %v", err)
		return
	}
	log.Printf("%s connected", userName)
	playerlistChannel := make(chan string, 10)
	defer func() {
		r.mux.Lock()
		delete(r.clients, userName)
		r.mux.Unlock()
		r.syncConfig.ReleasePlayerID(playerID)
		r.playerList.Unsubscribe(playerlistChannel)
		r.playerList.ReleasePlayerNum(playerNum)
	}()

	// Start a goroutine that forwards messages to the client.
	done := make(chan struct{})
	defer close(done)
	go func() {
		// Send the itemlist as part of initialization. This must happen before
		// all other messages in this loop or clients will disconnect.
		if err := (<-channel).Send(conn); err != nil {
			log.Printf("Failed to send itemlist to %s: %v", userName, err)
		}
		for {
			select {
			case msg := <-channel:
				if err := msg.Send(conn); err != nil {
					log.Printf("Failed to forward %s to %s: %v", msg, userName, err)
				}
				// If the server is quiting or if the player has been kicked,
				// close the connection.
				if (msg.MessageType == QUIT_MESSAGE && msg.FromUserName == SERVER_USER_NAME) ||
					msg.MessageType == KICK_PLAYER_MESSAGE {
					conn.Close()
				}
			case playerlist := <-playerlistChannel:
				msg := Message{
					MessageType:  PLAYER_LIST_MESSAGE,
					FromUserName: SERVER_USER_NAME,
					Payload:      playerlist,
				}
				if err := msg.Send(conn); err != nil {
					log.Printf("Failed to send playerlist to %s: %v", userName, err)
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
	// Subscribing to the playerlist will also cause it to be sent to this
	// client.
	r.sendItemList()
	r.playerList.Subscribe(playerlistChannel)

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
		case PLAYER_STATUS_MESSAGE:
			r.playerList.UpdateStatus(msg)
		// Suppress messages that should only be sent by the server.
		case KICK_PLAYER_MESSAGE:
		case PLAYER_LIST_MESSAGE:
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
		Payload:      "q:",
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

// Disconnects a single client from the room.
func (r *Room) Kick(userName string) error {
	kickMsg := &Message{
		MessageType:  KICK_PLAYER_MESSAGE,
		FromUserName: SERVER_USER_NAME,
	}
	// The quit message is sent to all other users to inform them that the user
	// was removed.
	quitMsg := &Message{
		MessageType:  QUIT_MESSAGE,
		FromUserName: userName,
		Payload:      "q:was_kicked",
	}
	log.Printf("Kicking %s...", userName)
	r.mux.RLock()
	defer r.mux.RUnlock()
	if _, ok := r.clients[userName]; !ok {
		return fmt.Errorf("%w %s", ErrUnknownUser, userName)
	}
	for name, channel := range r.clients {
		if name == userName {
			channel <- kickMsg
		} else {
			channel <- quitMsg
		}
	}
	return nil
}

// Performs initial configuration, including syncing configs with the client.
func (r *Room) initializeConnection(scanner *bufio.Scanner, conn io.ReadWriteCloser, channel chan *Message) (string, PlayerID, PlayerNum, error) {
	// The first thing the client sends should be its config.
	if !scanner.Scan() {
		if err := scanner.Err(); err != nil {
			return "", 0, 0, err
		}
		return "", 0, 0, ErrConnectionClosed
	}
	msg, err := DecodeMessage(scanner.Text())
	if err != nil {
		return "", 0, 0, err
	}
	playerID, err := r.syncConfig.ValidateClientConfig(msg)
	if err != nil {
		return "", 0, 0, err
	}

	// Clients should immediately receive their configuration.
	configMsg := Message{
		MessageType:  CONFIG_MESSAGE,
		FromUserName: SERVER_USER_NAME,
		Payload:      r.syncConfig.ConfigMessagePayload(playerID),
	}
	if err := configMsg.Send(conn); err != nil {
		r.syncConfig.ReleasePlayerID(playerID)
		return "", 0, 0, fmt.Errorf("error sending config: %w", err)
	}

	// Clients expect the server's player number. This value must be unique, so
	// we send 0 which can never be used by a client.
	playerNumberMsg := Message{
		MessageType:  PLAYER_NUMBER_MESSAGE,
		FromUserName: SERVER_USER_NAME,
		Payload:      fmt.Sprintf("%s,0", SERVER_USER_NAME),
	}
	if err := playerNumberMsg.Send(conn); err != nil {
		r.syncConfig.ReleasePlayerID(playerID)
		return "", 0, 0, fmt.Errorf("error sending player number: %w", err)
	}

	// Then clients send their player number.
	if !scanner.Scan() {
		r.syncConfig.ReleasePlayerID(playerID)
		if err := scanner.Err(); err != nil {
			return "", 0, 0, err
		}
		return "", 0, 0, ErrConnectionClosed
	}
	msg, err = DecodeMessage(scanner.Text())
	if err != nil {
		r.syncConfig.ReleasePlayerID(playerID)
		return "", 0, 0, err
	}
	playerNum, err := r.playerList.ValidatePlayerNumber(msg)
	if err != nil {
		r.syncConfig.ReleasePlayerID(playerID)
		return "", 0, 0, err
	}

	r.mux.Lock()
	if _, ok := r.clients[msg.FromUserName]; ok {
		r.mux.Unlock()
		r.syncConfig.ReleasePlayerID(playerID)
		r.playerList.ReleasePlayerNum(playerNum)
		return "", 0, 0, fmt.Errorf("%w, name=%s", ErrSyncUserNameInUse, msg.FromUserName)
	}
	r.clients[msg.FromUserName] = channel
	r.mux.Unlock()

	return msg.FromUserName, playerID, playerNum, nil
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
