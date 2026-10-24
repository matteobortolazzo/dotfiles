package main

import "testing"

// Shape captured from the live socket on 2026-10-24.
const liveSnapshot = `{"timestamp":"2026-10-24T11:02:03.123456789+02:00","windows":[` +
	`{"session":"cenci","window_index":"2","pane_id":"%83","window_name":"1337-implement","task_name":"Claude Code","status":"running","agent":"claude","manually_named":true},` +
	`{"session":"cenci","window_index":"5","pane_id":"%90","window_name":"1103-implement","task_name":"x","status":"done","agent":"claude"},` +
	`{"session":"work","window_index":"1","pane_id":"%91","window_name":"scratch","task_name":"y","status":"idle","agent":"codex"},` +
	`{"session":"cenci","window_index":"3","pane_id":"%84","window_name":"42-refine","task_name":"z","status":"need_input","agent":"claude"},` +
	`{"session":"cenci","window_index":"4","pane_id":"%85","window_name":"78-implement","task_name":"w","status":"failed","agent":"codex"}],` +
	`"summary":{"total":5,"idle":1,"running":1,"done":1,"stopped":0,"need_input":1,"failed":1,"escalated":0},` +
	`"dispatch":{"enabled":true,"daemon_running":true,"pass_running":false,"last_dispatched":2,"last_skipped":1}}`

func TestDecodeSnapshotSorted(t *testing.T) {
	s, err := decodeSnapshot([]byte(liveSnapshot))
	if err != nil {
		t.Fatal(err)
	}
	var order []string
	for _, w := range s.Windows {
		order = append(order, w.Status)
	}
	want := []string{"need_input", "failed", "running", "done", "idle"}
	for i := range want {
		if order[i] != want[i] {
			t.Fatalf("order %v, want %v", order, want)
		}
	}
	if s.Summary.Total != 5 || !s.Dispatch.Enabled || s.Dispatch.LastDispatched != 2 {
		t.Errorf("summary/dispatch: %+v %+v", s.Summary, s.Dispatch)
	}
	if s.Windows[0].PaneID != "%84" || s.Windows[0].WindowName != "42-refine" {
		t.Errorf("first window %+v", s.Windows[0])
	}
	if _, err := decodeSnapshot([]byte("{not json")); err == nil {
		t.Error("bad json: want error")
	}
}

func TestSortTieBreakAndUnknownStatus(t *testing.T) {
	ws := []Window{
		{Session: "b", WindowIndex: "1", Status: "running"},
		{Session: "a", WindowIndex: "2", Status: "weird"},
		{Session: "a", WindowIndex: "1", Status: "running"},
		{Session: "a", WindowIndex: "3", Status: "escalated"},
	}
	sortWindows(ws)
	got := []string{ws[0].Status + ws[0].Session, ws[1].Session + ws[1].WindowIndex, ws[2].Session, ws[3].Status}
	want := []string{"escalateda", "a1", "b", "weird"}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("got %v, want %v", got, want)
		}
	}
}

func TestShortName(t *testing.T) {
	if h, r := shortName("1337-implement"); h != "#1337" || r != "implement" {
		t.Errorf("got %q %q", h, r)
	}
	if h, r := shortName("scratch"); h != "scratch" || r != "" {
		t.Errorf("got %q %q", h, r)
	}
}
