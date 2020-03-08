package main

import (
	"errors"
	"fmt"
	"reflect"
	"sort"
	"strings"
	"testing"
)

func TestPlayerlistWithoutPlayers(t *testing.T) {
	pl := NewPlayerList()
	if playerlist := pl.Playerlist(); playerlist != "" {
		t.Errorf("got %s, want ''", playerlist)
	}
}

func TestPlayerlist(t *testing.T) {
	const playercount = 9
	pl := NewPlayerList()
	nums := make([]PlayerNum, 4)
	for i, _ := range nums {
		name := fmt.Sprintf("Player%d", i+1)
		msg := &Message{PLAYER_NUMBER_MESSAGE, name, fmt.Sprintf("%s,%d", name, i+1)}
		var err error
		if nums[i], err = pl.ValidatePlayerNumber(msg); err != nil {
			t.Fatalf("failed to validate player number message: %v", err)
		}
	}
	// Remove player 2 so that there's a gap in player numbers.
	pl.ReleasePlayerNum(2)

	// The order of entries in the playerlist depends on map iteration order.
	playerlist := strings.Split(pl.Playerlist(), ",")
	sort.Strings(playerlist)
	want := []string{"l:Player1:1", "l:Player3:3", "l:Player4:4"}
	if !reflect.DeepEqual(playerlist, want) {
		t.Errorf("got %v, want %v", playerlist, want)
	}
}

func TestValidatePlayerNumber(t *testing.T) {
	var tests = []struct {
		msg  *Message
		want error
	}{
		{&Message{PLAYER_NUMBER_MESSAGE, "Name", "Name"}, nil},
		{&Message{PLAYER_NUMBER_MESSAGE, "Name", "Name,"}, nil},
		{&Message{PLAYER_NUMBER_MESSAGE, "Name", "Name,1"}, nil},
		{&Message{MEMORY_MESSAGE, "Name", "Name"}, ErrPlayerNumWrongMessageType},
		{&Message{PLAYER_NUMBER_MESSAGE, "Name", "name"}, ErrPlayerNumPayload},
	}

	for _, tt := range tests {
		pl := NewPlayerList()
		if _, err := pl.ValidatePlayerNumber(tt.msg); !errors.Is(err, tt.want) {
			t.Errorf("got %v, want %v", err, tt.want)
		}
	}
}

func TestValidatePlayerNumberWithFoo(t *testing.T) {
	pl := NewPlayerList()
	msg := Message{PLAYER_NUMBER_MESSAGE, "Name", "Name,1"}
	if _, err := pl.ValidatePlayerNumber(&msg); err != nil {
		t.Fatalf("validation failed: %v", err)
	}
	if _, err := pl.ValidatePlayerNumber(&msg); !errors.Is(err, ErrPlayerNumInUse) {
		t.Errorf("got %v, want %v", err, ErrPlayerNumInUse)
	}
}

func TestPlayerNums(t *testing.T) {
	pl := NewPlayerList()
	msg := &Message{PLAYER_NUMBER_MESSAGE, "Name", "Name"}
	nums := make([]PlayerNum, 5)
	for i, _ := range nums {
		var err error
		if nums[i], err = pl.ValidatePlayerNumber(msg); err != nil {
			t.Errorf("failed to validate player number message: %v", err)
		}
	}
	want := []PlayerNum{1, 2, 3, 4, 5}
	if !reflect.DeepEqual(nums, want) {
		t.Errorf("got %v, want %v", nums, want)
	}

	// Release numbers 2 and 4; the next validation call should return these
	// values (in order) before returning 6.
	pl.ReleasePlayerNum(2)
	pl.ReleasePlayerNum(4)
	nums = make([]PlayerNum, 3)
	for i, _ := range nums {
		var err error
		if nums[i], err = pl.ValidatePlayerNumber(msg); err != nil {
			t.Errorf("failed to validate player number message: %v", err)
		}
	}
	want = []PlayerNum{2, 4, 6}
	if !reflect.DeepEqual(nums, want) {
		t.Errorf("got %v, want %v", nums, want)
	}
}
