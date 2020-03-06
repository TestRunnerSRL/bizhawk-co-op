package main

import (
	"errors"
	"fmt"
	"log"
	"math/rand"
	"strings"
	"sync"
)

var (
	ErrSyncWrongMessageType = errors.New("wrong message type")
	ErrSyncBadHash          = errors.New("bad sync hash")
)

// SyncConfig handles making sure that clients and servers are using the same
// lua scripts (sync hash) and ramcontroller configuration (ram config and item
// count).
type SyncConfig struct {
	// A hash of the Lua scripts used to ensure clients use the same version.
	syncHash string
	// Configuration for the ramcontroller.
	ramConfig string
	// The number of items used by the ramcontroller.
	itemCount int

	mux       sync.Mutex
	playerIDs map[PlayerID]struct{} // guarded by mux
}

// Each connection is assigned a unique player id.
type PlayerID int

// Creates a new SyncConfig with the provided properties.
func NewSyncConfig(syncHash string, ramConfig string, itemCount int) *SyncConfig {
	return &SyncConfig{
		syncHash:  syncHash,
		ramConfig: ramConfig,
		itemCount: itemCount,
		playerIDs: make(map[PlayerID]struct{}),
	}
}

// Returns the payload string that should be sent by the server in
// CONFIG_MESSAGEs.
func (sc *SyncConfig) ConfigMessagePayload(id PlayerID) string {
	// We send each client clientId 1 since it's unused.
	return fmt.Sprintf("%s,%d,%s", sc.syncHash, id, sc.ramConfig)
}

// Returns the payload string that should be sent by the server for the
// initial itemlist.
func (sc *SyncConfig) Itemlist() string {
	// Build an array containing all player ids (in an unspecified order).
	sc.mux.Lock()
	playerIDs := make([]PlayerID, 0, len(sc.playerIDs))
	for id, _ := range sc.playerIDs {
		playerIDs = append(playerIDs, id)
	}
	sc.mux.Unlock()

	// To avoid errors when there are no players connected, assign all items
	// to player 1 (which will never be used).
	if len(playerIDs) == 0 {
		log.Printf("Itemlist requested with no players connected")
		playerIDs = append(playerIDs, 1)
	}

	// Uniformly (but randomly) distribute the items across all players.
	itemlist := make([]PlayerID, sc.itemCount)
	for i, _ := range itemlist {
		itemlist[i] = playerIDs[i%len(playerIDs)]
	}
	rand.Shuffle(len(itemlist), func(i, j int) {
		itemlist[i], itemlist[j] = itemlist[j], itemlist[i]
	})

	// Construct the itemlist string returned to clients.
	var sb strings.Builder
	for i, id := range itemlist {
		sb.WriteString(fmt.Sprintf("i:%d:%d,", i, id))
	}
	// Omit the trailing comma.
	return sb.String()[0 : sb.Len()-1]
}

// Validates the first message sent by clients, which should be their
// CONFIG_MESSAGE. Returns the player id for the new connection. The
// player id should be released when the connection closes.
func (sc *SyncConfig) ValidateClientConfig(msg *Message) (PlayerID, error) {
	if msg.MessageType != CONFIG_MESSAGE {
		return 0, ErrSyncWrongMessageType
	}
	if msg.Payload != sc.syncHash {
		return 0, ErrSyncBadHash
	}

	// Iterate until we find an unused PlayerID. This could be made more
	// efficient than O(N), but Itemlist() is also called whenever a new player
	// joins, and that function is also O(N + I log I), where I is the number
	// of items. As a result, it's not worthwhile to make this loop more
	// efficient.
	sc.mux.Lock()
	id := PlayerID(2) // Clients require 1 to be reserved for the host.
	for ; ; id++ {
		if _, ok := sc.playerIDs[id]; !ok {
			break
		}
	}
	sc.playerIDs[id] = struct{}{}
	sc.mux.Unlock()
	return id, nil
}

func (sc *SyncConfig) ReleasePlayerID(id PlayerID) {
	// While it may be possible to decrease maxPlayerID here, we don't because
	// we don't know how ramcontrollers will handle seeing the player count
	// decrease. This should be revisited if it becomes common for players
	// to drop out of the game without replacement.
	sc.mux.Lock()
	delete(sc.playerIDs, id)
	sc.mux.Unlock()
}
