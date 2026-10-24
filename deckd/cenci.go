package main

// Row 2: cenci's NDJSON snapshot stream on ~/.local/state/cenci/run/cenci.sock.

import (
	"bufio"
	"context"
	"encoding/json"
	"log"
	"net"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"time"
)

type Window struct {
	Session     string `json:"session"`
	WindowIndex string `json:"window_index"`
	PaneID      string `json:"pane_id"`
	WindowName  string `json:"window_name"`
	TaskName    string `json:"task_name"`
	Status      string `json:"status"`
	Agent       string `json:"agent"`
}

type Summary struct {
	Total     int `json:"total"`
	Idle      int `json:"idle"`
	Running   int `json:"running"`
	Done      int `json:"done"`
	Stopped   int `json:"stopped"`
	NeedInput int `json:"need_input"`
	Failed    int `json:"failed"`
	Escalated int `json:"escalated"`
}

type Dispatch struct {
	Enabled        bool `json:"enabled"`
	DaemonRunning  bool `json:"daemon_running"`
	PassRunning    bool `json:"pass_running"`
	LastDispatched int  `json:"last_dispatched"`
	LastSkipped    int  `json:"last_skipped"`
}

type Snapshot struct {
	Timestamp time.Time `json:"timestamp"`
	Windows   []Window  `json:"windows"`
	Summary   Summary   `json:"summary"`
	Dispatch  Dispatch  `json:"dispatch"`
}

// statusOrder: what wants you first sorts first.
var statusOrder = map[string]int{
	"need_input": 0, "failed": 1, "escalated": 2, "running": 3,
	"done": 4, "stopped": 5, "idle": 6,
}

func statusRank(s string) int {
	if r, ok := statusOrder[s]; ok {
		return r
	}
	return len(statusOrder)
}

func decodeSnapshot(line []byte) (*Snapshot, error) {
	var s Snapshot
	if err := json.Unmarshal(line, &s); err != nil {
		return nil, err
	}
	sortWindows(s.Windows)
	return &s, nil
}

func sortWindows(ws []Window) {
	sort.SliceStable(ws, func(i, j int) bool {
		a, b := ws[i], ws[j]
		if ra, rb := statusRank(a.Status), statusRank(b.Status); ra != rb {
			return ra < rb
		}
		if a.Session != b.Session {
			return a.Session < b.Session
		}
		return a.WindowIndex < b.WindowIndex
	})
}

var ticketRe = regexp.MustCompile(`^(\d+)-(.+)$`)

// shortName splits "1337-implement" into "#1337" and "implement"; anything
// without a ticket prefix is shown as is.
func shortName(windowName string) (head, rest string) {
	if m := ticketRe.FindStringSubmatch(windowName); m != nil {
		return "#" + m[1], m[2]
	}
	return windowName, ""
}

func cenciSocket() string {
	return filepath.Join(os.Getenv("HOME"), ".local", "state", "cenci", "run", "cenci.sock")
}

// watchCenci keeps a connection to the socket and sends every snapshot, or
// nil whenever the daemon is gone. It returns when ctx is cancelled.
func watchCenci(ctx context.Context, path string, out chan<- *Snapshot) {
	backoff := time.Second
	connected := true // so the first failure is reported
	for ctx.Err() == nil {
		var d net.Dialer
		conn, err := d.DialContext(ctx, "unix", path)
		if err == nil {
			backoff = time.Second
			stop := context.AfterFunc(ctx, func() { conn.Close() })
			sc := bufio.NewScanner(conn)
			sc.Buffer(make([]byte, 64*1024), 4*1024*1024)
			for sc.Scan() {
				snap, err := decodeSnapshot(sc.Bytes())
				if err != nil {
					log.Printf("cenci: bad snapshot: %v", err)
					continue
				}
				connected = true
				select {
				case out <- snap:
				case <-ctx.Done():
				}
			}
			stop()
			conn.Close()
			err = sc.Err()
		}
		if connected && ctx.Err() == nil {
			log.Printf("cenci: no daemon (%v)", err)
			connected = false
			select {
			case out <- nil:
			case <-ctx.Done():
			}
		}
		select {
		case <-time.After(backoff):
		case <-ctx.Done():
		}
		backoff = min(backoff*2, 10*time.Second)
	}
}
