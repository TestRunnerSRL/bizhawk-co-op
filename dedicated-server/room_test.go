package main

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"log"
	"os"
	"reflect"
	"strings"
	"testing"
)

type FakeConn struct {
	input  io.Reader
	output io.Writer
	closed bool
}

func (f *FakeConn) Read(buf []byte) (int, error) {
	return f.input.Read(buf)
}

func (f *FakeConn) Write(buf []byte) (int, error) {
	return f.output.Write(buf)
}

func (f *FakeConn) Close() error {
	f.closed = true
	if r, ok := f.input.(io.ReadCloser); ok {
		r.Close()
	}
	if w, ok := f.output.(io.WriteCloser); ok {
		w.Close()
	}
	return nil
}

type FakeSyncConfig struct {
	validateErr   error
	clientConfigs []*Message
	releaseCalls  int
}

func (sc *FakeSyncConfig) ConfigMessagePayload(id PlayerID) string {
	return fmt.Sprintf("configPayload%d", id)
}
func (sc *FakeSyncConfig) Itemlist() string         { return "itemPayload" }
func (sc *FakeSyncConfig) ReleasePlayerID(PlayerID) { sc.releaseCalls++ }
func (sc *FakeSyncConfig) ValidateClientConfig(msg *Message) (PlayerID, error) {
	sc.clientConfigs = append(sc.clientConfigs, msg)
	return PlayerID(len(sc.clientConfigs)), sc.validateErr
}

func TestMessagePropagation(t *testing.T) {
	sc := &FakeSyncConfig{}
	room := NewRoom(sc)
	done := make(chan bool, 1)
	r1, writer1 := io.Pipe()
	reader1, w1 := io.Pipe()
	conn1 := FakeConn{input: r1, output: w1}
	go func() {
		room.HandleConnection(&conn1)
		done <- true
	}()

	// First the server expects our config.
	if _, err := fmt.Fprintf(writer1, "cP1,syncHash\n"); err != nil {
		t.Errorf("conn1: failed to write config: %v", err)
	}

	// Then the server sends its config.
	configMessage := "cServer,configPayload1"
	scanner1 := bufio.NewScanner(reader1)
	if scanner1.Scan(); scanner1.Text() != configMessage {
		t.Errorf("conn1: got config %s, want %s", scanner1.Text(), configMessage)
	}

	// Then the server sends the itemlist.
	itemList := "rServer,itemPayload"
	if scanner1.Scan(); scanner1.Text() != itemList {
		t.Errorf("conn1: got itemlist %s, want %s", scanner1.Text(), itemList)
	}

	r2, writer2 := io.Pipe()
	reader2, w2 := io.Pipe()
	conn2 := FakeConn{input: r2, output: w2}
	go func() {
		room.HandleConnection(&conn2)
		done <- true
	}()

	scanner2 := bufio.NewScanner(reader2)
	if _, err := fmt.Fprintf(writer2, "cP2,syncHash\n"); err != nil {
		t.Errorf("conn2: failed to write config: %v", err)
	}
	configMessage = "cServer,configPayload2"
	if scanner2.Scan(); scanner2.Text() != configMessage {
		t.Errorf("conn2: got config %s, want %s", scanner2.Text(), configMessage)
	}
	// The itemlist is send to both players, in any order.
	go func() {
		if scanner1.Scan(); scanner1.Text() != itemList {
			t.Errorf("conn1: got itemlist %s, want %s", scanner1.Text(), itemList)
		}
		done <- true
	}()
	go func() {
		if scanner2.Scan(); scanner2.Text() != itemList {
			t.Errorf("conn2: got itemlist %s, want %s", scanner2.Text(), itemList)
		}
		done <- true
	}()
	<-done
	<-done

	// Write a message to P1. It should be forwarded to P2.
	want := "mP1,payload"
	if _, err := fmt.Fprintf(writer1, "%s\n", want); err != nil {
		t.Errorf("conn1: failed to message: %v", err)
	}
	if scanner2.Scan(); scanner2.Text() != want {
		t.Errorf("conn2: got message %s, want %s", scanner2.Text(), want)
	}

	// Close the inputs. HandleConnection should close the outputs before returning.
	writer1.Close()
	writer2.Close()
	<-done
	<-done
	if !conn1.closed || !conn2.closed {
		t.Errorf("connections were not closed")
	}

	// Verify the configs sent to the SyncConfig.
	var wantConfigs = []*Message{
		&Message{CONFIG_MESSAGE, "P1", "syncHash"},
		&Message{CONFIG_MESSAGE, "P2", "syncHash"},
	}
	if !reflect.DeepEqual(sc.clientConfigs, wantConfigs) {
		t.Errorf("unexpected config messages: got %v, want %v", sc.clientConfigs, wantConfigs)
	}
}

func TestClose(t *testing.T) {
	room := NewRoom(&FakeSyncConfig{})
	reader, writer := io.Pipe()
	var buf bytes.Buffer
	conn := FakeConn{input: reader, output: &buf}
	go room.HandleConnection(&conn)

	if _, err := fmt.Fprintf(writer, "cP1,syncHash\n"); err != nil {
		t.Errorf("failed to write config: %v", err)
	}
	// Write another message to ensure we're beyond the initial handshake.
	if _, err := fmt.Fprintf(writer, "pP1,\n"); err != nil {
		t.Errorf("failed to write ping: %v", err)
	}

	room.Close()
	if !conn.closed {
		t.Errorf("connection was not closed")
	}
	want := "cServer,configPayload1\n" +
		"rServer,itemPayload\n" +
		"qServer,\n"
	if buf.String() != want {
		t.Errorf("got %s, want %s", buf.String(), want)
	}
}

func TestSyncFailures(t *testing.T) {
	var tests = []struct {
		input     string
		syncError error
		want      error
	}{
		{"", nil, ErrConnectionClosed},
		{"x,\n", nil, ErrUnknownMessageType},
		{"c,syncHash\n", ErrSyncBadHash, ErrSyncBadHash},
	}

	defer log.SetOutput(os.Stderr)
	for _, tt := range tests {
		var buf bytes.Buffer
		log.SetOutput(&buf)
		room := NewRoom(&FakeSyncConfig{validateErr: tt.syncError})
		conn := FakeConn{input: bytes.NewBufferString(tt.input), output: new(bytes.Buffer)}
		room.HandleConnection(&conn)
		if !conn.closed {
			t.Errorf("connection wasn't closed for %s", tt.input)
		}
		if !strings.Contains(buf.String(), tt.want.Error()) {
			t.Errorf("expected %s in logs, got %s", tt.want.Error(), buf.String())
		}
	}
}

func TestDuplicateUserName(t *testing.T) {
	room := NewRoom(&FakeSyncConfig{})
	done := make(chan bool, 1)

	r1, writer1 := io.Pipe()
	conn1 := FakeConn{input: r1, output: new(bytes.Buffer)}
	go room.HandleConnection(&conn1)
	if _, err := fmt.Fprintf(writer1, "cP,syncHash\n"); err != nil {
		t.Errorf("conn1: failed to write config: %v", err)
	}
	// Write another message to ensure we're beyond the initial handshake.
	if _, err := fmt.Fprintf(writer1, "pP1,\n"); err != nil {
		t.Errorf("failed to write ping: %v", err)
	}

	r2, writer2 := io.Pipe()
	conn2 := FakeConn{input: r2, output: new(bytes.Buffer)}
	go func() {
		room.HandleConnection(&conn2)
		done <- true
	}()
	var buf bytes.Buffer
	log.SetOutput(&buf)
	if _, err := fmt.Fprintf(writer2, "cP,syncHash\n"); err != nil {
		t.Errorf("conn2: failed to write config: %v", err)
	}
	<-done
	log.SetOutput(os.Stderr)

	// P2s connection should have closed with an error.
	if !conn2.closed {
		t.Errorf("conn2 was not closed")
	}
	if !strings.Contains(buf.String(), ErrSyncUserNameInUse.Error()) {
		t.Errorf("expected %s in logs, got %s", ErrSyncUserNameInUse.Error(), buf.String())
	}
	if conn1.closed {
		t.Errorf("conn was not closed")
	}
}

// Note: pings currently aren't tested due to time.Ticker being difficult to
// fake in tests.
