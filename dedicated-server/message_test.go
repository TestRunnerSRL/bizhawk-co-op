package main

import (
	"bytes"
	"errors"
	"testing"
)

func TestMessageTypeString(t *testing.T) {
	var tests = []struct {
		mt   MessageType
		want string
	}{
		{CONFIG_MESSAGE, "CONFIG_MESSAGE"},
		{KICK_PLAYER_MESSAGE, "KICK_PLAYER_MESSAGE"},
		{PLAYER_LIST_MESSAGE, "PLAYER_LIST_MESSAGE"},
		{MEMORY_MESSAGE, "MEMORY_MESSAGE"},
		{PLAYER_NUMBER_MESSAGE, "PLAYER_NUMBER_MESSAGE"},
		{PING_MESSAGE, "PING_MESSAGE"},
		{QUIT_MESSAGE, "QUIT_MESSAGE"},
		{RAM_EVENT_MESSAGE, "RAM_EVENT_MESSAGE"},
		{PLAYER_STATUS_MESSAGE, "PLAYER_STATUS_MESSAGE"},
		{'x', "UNKNOWN(x)"},
	}

	for _, tt := range tests {
		if ans := tt.mt.String(); ans != tt.want {
			t.Errorf("got %s, want %s", ans, tt.want)
		}
	}
}

func TestDecodeMessage(t *testing.T) {
	var tests = []struct {
		encoded string
		want    Message
	}{
		{"cUser,Payload", Message{CONFIG_MESSAGE, "User", "Payload"}},
		{"kUser,Payload", Message{KICK_PLAYER_MESSAGE, "User", "Payload"}},
		{"lUser,Payload", Message{PLAYER_LIST_MESSAGE, "User", "Payload"}},
		{"mUser,Payload", Message{MEMORY_MESSAGE, "User", "Payload"}},
		{"nUser,Payload", Message{PLAYER_NUMBER_MESSAGE, "User", "Payload"}},
		{"pUser,", Message{PING_MESSAGE, "User", ""}},
		{"qUser,", Message{QUIT_MESSAGE, "User", ""}},
		{"rUser,Payload", Message{RAM_EVENT_MESSAGE, "User", "Payload"}},
		{"sUser,Payload", Message{PLAYER_STATUS_MESSAGE, "User", "Payload"}},
	}

	for _, tt := range tests {
		ans, err := DecodeMessage(tt.encoded)
		if err != nil {
			t.Errorf("decoding %s failed: %v", tt.encoded, err)
		}
		if *ans != tt.want {
			t.Errorf("got %s, want %s", ans, tt.want)
		}
	}
}

func TestDecodeMessageFailure(t *testing.T) {
	var tests = []struct {
		encoded string
		want    error
	}{
		{"", ErrEmptyMessage},
		{"xUser,Payload", ErrUnknownMessageType},
		{"cNoPayload", ErrMalformedMessage},
	}

	for _, tt := range tests {
		if _, err := DecodeMessage(tt.encoded); !errors.Is(err, tt.want) {
			t.Errorf("got %v, want %v", err, tt.want)
		}
	}
}

func TestSend(t *testing.T) {
	buf := new(bytes.Buffer)
	msg := Message{MEMORY_MESSAGE, "User", "Payload"}
	expected := "mUser,Payload\n"
	if err := msg.Send(buf); err != nil {
		t.Fatalf("unexpected Send failure: %s", err)
	} else if buf.String() != expected {
		t.Fatalf("got %s, expected %s", buf.String(), expected)
	}
}
