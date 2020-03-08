package main

import (
	"errors"
	"fmt"
	"strconv"
	"strings"
	"sync"
)

var (
	ErrPlayerNumWrongMessageType = errors.New("wrong message type")
	ErrPlayerNumPayload          = errors.New("invalid message payload")
	ErrPlayerNumInUse            = errors.New("player number in use")
)

// PlayerList keeps track of which players are connected.
type PlayerList struct {
	mux     sync.Mutex
	players map[PlayerNum]string
}

// Each player reports their unique player number.
type PlayerNum int

func NewPlayerList() *PlayerList {
	return &PlayerList{
		players: make(map[PlayerNum]string),
	}
}

// Returns a payload string encoding the currently connected players. The
// server is never included.
func (pl *PlayerList) Playerlist() string {
	var sb strings.Builder
	pl.mux.Lock()
	for num, name := range pl.players {
		sb.WriteString(fmt.Sprintf("l:%s:%d,", name, num))
	}
	pl.mux.Unlock()
	if sb.Len() == 0 {
		return ""
	} else {
		return sb.String()[0 : sb.Len()-1]
	}
}

// Validates the PLAYER_NUMBER_MESSAGE sent by clients, ensuring that the
// self-reported number is unique.
func (pl *PlayerList) ValidatePlayerNumber(msg *Message) (PlayerNum, error) {
	if msg.MessageType != PLAYER_NUMBER_MESSAGE {
		return 0, ErrPlayerNumWrongMessageType
	}

	// Determine the player number. If it's empty, the server is supposed to
	// pick the next available value.
	parts := strings.SplitN(msg.Payload, ",", 2)
	if parts[0] != msg.FromUserName {
		return 0, ErrPlayerNumPayload
	}
	if len(parts) == 1 || parts[1] == "" {
		pl.mux.Lock()
		for num := PlayerNum(1); ; num++ {
			if _, ok := pl.players[num]; !ok {
				pl.players[num] = msg.FromUserName
				pl.mux.Unlock()
				return num, nil
			}
		}
	} else {
		num, err := strconv.Atoi(parts[1])
		if err != nil {
			return 0, fmt.Errorf("bad player number: %w", err)
		}
		pl.mux.Lock()
		defer pl.mux.Unlock()
		if name, ok := pl.players[PlayerNum(num)]; ok {
			return 0, fmt.Errorf("%w by %s", ErrPlayerNumInUse, name)
		}
		pl.players[PlayerNum(num)] = msg.FromUserName
		return PlayerNum(num), nil
	}
}

func (pl *PlayerList) ReleasePlayerNum(num PlayerNum) {
	pl.mux.Lock()
	delete(pl.players, num)
	pl.mux.Unlock()
}
