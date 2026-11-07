# Build on Tom (arm64): `make` produces ./petcam and systemd runs it.
BIN := petcam
SRC := $(wildcard *.go go.mod templates/*.html)

.PHONY: all test clean
all: $(BIN)

$(BIN): $(SRC)
	go build -o $(BIN) .

test:
	go test ./...

clean:
	rm -f $(BIN)
