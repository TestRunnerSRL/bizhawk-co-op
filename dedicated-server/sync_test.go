package main

import (
	"errors"
	"testing"
)

func TestConfigMessagePayload(t *testing.T) {
	sc := NewSyncConfig("syncHash", "ramConfig")
	want := "syncHash,1,ramConfig"
	if payload := sc.ConfigMessagePayload(); payload != want {
		t.Errorf("got %s, want %s", payload, want)
	}
}

func TestItemlist(t *testing.T) {
	sc := NewSyncConfig("syncHash", "ramConfig")
	want := "i:0:1"
	if itemlist := sc.Itemlist(); itemlist != want {
		t.Errorf("got %s, want %s", itemlist, want)
	}
}

func TestValidateClientConfig(t *testing.T) {
	var tests = []struct {
		msg  *Message
		want error
	}{
		{&Message{CONFIG_MESSAGE, "", "syncHash"}, nil},
		{&Message{MEMORY_MESSAGE, "", "syncHash"}, ErrSyncWrongMessageType},
		{&Message{CONFIG_MESSAGE, "", "badHash"}, ErrSyncBadHash},
	}

	for _, tt := range tests {
		sc := NewSyncConfig("syncHash", "ramConfig")
		if err := sc.ValidateClientConfig(tt.msg); !errors.Is(err, tt.want) {
			t.Errorf("got %v, want %v", err, tt.want)
		}
	}
}
