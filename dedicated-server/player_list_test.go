package main

import (
	"bytes"
	"errors"
	"fmt"
	"log"
	"os"
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
	for i := 1; i < 5; i++ {
		name := fmt.Sprintf("Player%d", i)
		msg := &Message{PLAYER_NUMBER_MESSAGE, name, fmt.Sprintf("%s,%d", name, i)}
		if _, err := pl.ValidatePlayerNumber(msg); err != nil {
			t.Fatalf("failed to validate player number message: %v", err)
		}
	}
	// Remove player 2 so that there's a gap in player numbers.
	pl.ReleasePlayerNum(2)

	// The order of entries in the playerlist depends on map iteration order.
	playerlist := strings.Split(pl.Playerlist(), ",")
	sort.Strings(playerlist)
	want := []string{
		"l:Player1:num:1",
		"l:Player1:status:Unready",
		"l:Player3:num:3",
		"l:Player3:status:Unready",
		"l:Player4:num:4",
		"l:Player4:status:Unready",
	}
	if !reflect.DeepEqual(playerlist, want) {
		t.Errorf("got %v, want %v", playerlist, want)
	}
}

func TestUpdateStatus(t *testing.T) {
	pl := NewPlayerList()
	msg := &Message{PLAYER_NUMBER_MESSAGE, "Name", "Name,10"}
	if _, err := pl.ValidatePlayerNumber(msg); err != nil {
		t.Fatalf("failed to validate player number message: %v", err)
	}
	pl.UpdateStatus(&Message{PLAYER_STATUS_MESSAGE, "Name", "Name,Status"})

	want := "l:Name:num:10,l:Name:status:Status"
	if playerlist := pl.Playerlist(); playerlist != want {
		t.Errorf("got %s, want %s", playerlist, want)
	}
}

func TestUpdateStatusFailures(t *testing.T) {
	playerNumberMsg := &Message{PLAYER_NUMBER_MESSAGE, "Name", "Name,1"}
	var tests = []struct {
		msg  *Message
		want string
	}{
		{&Message{PLAYER_NUMBER_MESSAGE, "", ""}, "invalid message type"},
		{&Message{PLAYER_STATUS_MESSAGE, "Name", "Name2,"}, "invalid player status message"},
		{&Message{PLAYER_STATUS_MESSAGE, "Name", "Name"}, "invalid player status message"},
		{&Message{PLAYER_STATUS_MESSAGE, "Other", "Other,Status"}, ""},
	}

	for _, tt := range tests {
		pl := NewPlayerList()
		if _, err := pl.ValidatePlayerNumber(playerNumberMsg); err != nil {
			t.Fatalf("Failed to validate player number message: %v", err)
		}
		want := pl.Playerlist() // The playerlist should not change.
		var buf bytes.Buffer
		log.SetOutput(&buf)
		pl.UpdateStatus(tt.msg)
		log.SetOutput(os.Stderr)
		if playerlist := pl.Playerlist(); playerlist != want {
			t.Fatalf("got %s, want %s", playerlist, want)
		}
		if !strings.Contains(buf.String(), tt.want) {
			t.Errorf("expected %s in logs, got %s", tt.want, buf.String())
		}
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

func TestSubscribe(t *testing.T) {
	pl := NewPlayerList()
	// Add a player so that the playerlist isn't empty.
	msg := &Message{PLAYER_NUMBER_MESSAGE, "Name", "Name,10"}
	if _, err := pl.ValidatePlayerNumber(msg); err != nil {
		t.Fatalf("failed to validate player number message: %v", err)
	}

	// When subscribing, the playerlist should immediately be sent.
	c := make(chan string, 1)
	go pl.Subscribe(c)
	defer pl.Unsubscribe(c)
	want := "l:Name:num:10,l:Name:status:Unready"
	if playerlist := <-c; playerlist != want {
		t.Errorf("got %s, want %s", playerlist, want)
	}

	// The playerlist should also be sent when the player number is released.
	go pl.ReleasePlayerNum(10)
	if playerlist := <-c; playerlist != "" {
		t.Errorf("got %s, want ''", playerlist)
	}

	// The playerlist should also be sent when a player joins.
	go pl.ValidatePlayerNumber(msg)
	if playerlist := <-c; playerlist != want {
		t.Errorf("got %s, want %s", playerlist, want)
	}
}
