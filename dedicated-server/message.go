package main

import (
	"errors"
	"fmt"
	"io"
	"strings"
)

type MessageType byte

const (
	// A message containing startup configuration information. The payload of a
	// CONFIG_MESSAGE from a client is the syncHash. The payload of a
	// CONFIG_MESSAGE from the server is "<synchash>,<clientIu>,<ramconfig>".
	CONFIG_MESSAGE MessageType = 'c'

	// A message indicating modifications that should be made to game memory.
	// The payload is a comma-separated list of "<addr>:<value>" pairs.
	MEMORY_MESSAGE MessageType = 'm'

	// A message used to keep the connection alive. There is no payload.
	PING_MESSAGE MessageType = 'p'

	// A message indicating the sender is disconnecting. No payload.
	QUIT_MESSAGE MessageType = 'q'

	// A message containing ramcontroller-specific information. The server
	// sends the itemlist ("i:...") when new clients connect; after that,
	// all ram event messages are unintepreted by the server.
	RAM_EVENT_MESSAGE MessageType = 'r'
)

var (
	ErrEmptyMessage       = errors.New("message is empty")
	ErrUnknownMessageType = errors.New("unsupported message type")
	ErrMalformedMessage   = errors.New("malformed message")
)

// Converts a MessageType to a string.
func (t MessageType) String() string {
	switch t {
	case CONFIG_MESSAGE:
		return "CONFIG_MESSAGE"
	case MEMORY_MESSAGE:
		return "MEMORY_MESSAGE"
	case PING_MESSAGE:
		return "PING_MESSAGE"
	case QUIT_MESSAGE:
		return "QUIT_MESSAGE"
	case RAM_EVENT_MESSAGE:
		return "RAM_EVENT_MESSAGE"
	default:
		return fmt.Sprintf("UNKNOWN(%c)", t)
	}
}

// A Message contains all information sent in a client/server message.
type Message struct {
	// The type of the message.
	MessageType MessageType
	// The name of the user from which the message was sent.
	FromUserName string
	// The payload of the message, which depends on the message type.
	Payload string
}

// Decodes a serialized message.
// The message format is "[type][fromUser],[payload]".
func DecodeMessage(serialized string) (*Message, error) {
	if len(serialized) == 0 {
		return nil, ErrEmptyMessage
	}

	// The first character of the message specifies its type.
	switch t := MessageType(serialized[0]); t {
	case CONFIG_MESSAGE:
	case MEMORY_MESSAGE:
	case PING_MESSAGE:
	case QUIT_MESSAGE:
	case RAM_EVENT_MESSAGE:
	default:
		return nil, ErrUnknownMessageType
	}

	// The user name is before the first comma, and the payload follows it.
	parts := strings.SplitN(serialized[1:], ",", 2)
	if len(parts) != 2 {
		return nil, ErrMalformedMessage
	}
	return &Message{MessageType(serialized[0]), parts[0], parts[1]}, nil
}

// Writes the message to the Writer.
func (m Message) Send(w io.Writer) error {
	_, err := fmt.Fprintf(w, "%c%s,%s\n", m.MessageType, m.FromUserName, m.Payload)
	return err
}
