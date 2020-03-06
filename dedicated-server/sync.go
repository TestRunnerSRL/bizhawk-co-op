package main

import (
	"errors"
	"fmt"
)

var (
	ErrSyncWrongMessageType = errors.New("wrong message type")
	ErrSyncBadHash          = errors.New("bad sync hash")
)

// SyncConfig handles making sure that clients and servers are using the same
// lua scripts (sync hash) and ramcontroller configuration (ram config).
type SyncConfig struct {
	// A hash of the Lua scripts used to ensure clients use the same version.
	syncHash string
	// Configuration for the ramcontroller.
	ramConfig string
}

// Creates a new SyncConfig with the provided sync hash and ram config.
func NewSyncConfig(syncHash string, ramConfig string) *SyncConfig {
	return &SyncConfig{syncHash, ramConfig}
}

// Returns the payload string that should be sent by the server in
// CONFIG_MESSAGEs.
func (sc *SyncConfig) ConfigMessagePayload() string {
	// We send each client clientId 1 since it's unused.
	return fmt.Sprintf("%s,1,%s", sc.syncHash, sc.ramConfig)
}

// Returns the payload string that should be sent by the server for the
// initial itemlist.
func (sc *SyncConfig) Itemlist() string {
	// TODO(bmclarnon): Get the itemcount from the ramcontroller to send proper
	// itemlists for non-OOT games.
	return "i:0:1"
}

// Validates the first message sent by clients, which should be their
// CONFIG_MESSAGE.
func (sc *SyncConfig) ValidateClientConfig(msg *Message) error {
	if msg.MessageType != CONFIG_MESSAGE {
		return ErrSyncWrongMessageType
	}
	if msg.Payload != sc.syncHash {
		return ErrSyncBadHash
	}
	return nil
}
