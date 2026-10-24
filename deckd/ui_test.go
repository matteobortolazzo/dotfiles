package main

import (
	"strings"
	"testing"
	"time"
)

func keysDown(ks ...int) [keyCount]bool {
	var s [keyCount]bool
	for _, k := range ks {
		s[k] = true
	}
	return s
}

func TestTapAndHoldClassification(t *testing.T) {
	var p pressTracker
	t0 := time.Unix(1000, 0)

	// Tap: ~0.1 s down-to-up.
	if got := p.Update(keysDown(3), t0); len(got) != 0 {
		t.Fatalf("down emitted %v", got)
	}
	if got := p.Update(keysDown(), t0.Add(100*time.Millisecond)); len(got) != 1 || got[0] != (press{3, tap}) {
		t.Fatalf("tap: got %v", got)
	}

	// Hold fires from Poll while still down, once, and release is silent.
	p.Update(keysDown(14), t0)
	if got := p.Poll(t0.Add(time.Second)); len(got) != 0 {
		t.Fatalf("early poll: %v", got)
	}
	if got := p.Poll(t0.Add(holdTime)); len(got) != 1 || got[0] != (press{14, hold}) {
		t.Fatalf("hold poll: %v", got)
	}
	if got := p.Poll(t0.Add(2 * holdTime)); len(got) != 0 {
		t.Fatalf("hold fired twice: %v", got)
	}
	if got := p.Update(keysDown(), t0.Add(2*holdTime)); len(got) != 0 {
		t.Fatalf("release after hold emitted %v", got)
	}

	// Long press released before any Poll still counts as a hold.
	p.Update(keysDown(5), t0)
	if got := p.Update(keysDown(), t0.Add(2*time.Second)); len(got) != 1 || got[0] != (press{5, hold}) {
		t.Fatalf("late release: %v", got)
	}

	// Repeated identical reports are not new presses.
	p.Update(keysDown(1), t0)
	p.Update(keysDown(1), t0.Add(50*time.Millisecond))
	if got := p.Update(keysDown(), t0.Add(80*time.Millisecond)); len(got) != 1 {
		t.Fatalf("duplicate report: %v", got)
	}
}

func lineTexts(tl Tile) string {
	var s []string
	for _, l := range tl.Lines {
		s = append(s, l.Text)
	}
	return strings.Join(s, "|")
}

func TestPowerKeyNeedsHoldThenPress(t *testing.T) {
	ui := NewUI(true, "exa")
	now := time.Now()
	ui.Press(press{14, tap}, now)
	if ui.page != pageMain {
		t.Fatal("a tap on power must not open the confirm page")
	}
	ui.Press(press{14, hold}, now)
	if ui.page != pagePower {
		t.Fatal("hold on power should open the confirm page")
	}
	ui.Press(press{12, tap}, now) // cancel
	if ui.page != pageMain {
		t.Fatal("cancel should return to main")
	}
	ui.Press(press{14, hold}, now)
	ui.Tick(now.Add(powerTimeout + time.Second))
	if ui.page != pageMain {
		t.Fatal("confirm page should time out")
	}
}

func TestUPSTakeover(t *testing.T) {
	ui := NewUI(true, "exa")
	t0 := time.Now()
	ui.page = pageAgents
	ui.SetStats(Stats{UPSOK: true, UPS: UPS{Status: "OB DISCHRG", Charge: 90}}, t0)
	tiles, _ := ui.frame(t0.Add(30 * time.Second))
	if got := lineTexts(tiles[4]); !strings.Contains(got, "4:30") {
		t.Fatalf("countdown tile = %q", got)
	}
	// upsc failing mid-outage keeps the takeover.
	ui.SetStats(Stats{}, t0.Add(time.Minute))
	if !ui.takeover() {
		t.Fatal("takeover lost on a failed probe")
	}
	ui.Press(press{10, tap}, t0) // back to normal view
	if ui.takeover() || ui.page != pageAgents {
		t.Fatal("dismiss should reveal the previous page")
	}
	ui.SetStats(Stats{UPSOK: true, UPS: UPS{Status: "OL CHRG"}}, t0.Add(2*time.Minute))
	if !ui.obSince.IsZero() || ui.upsDismissed {
		t.Fatal("OL should clear the outage")
	}
}

func TestAgentsRowOverflowAndActions(t *testing.T) {
	ui := NewUI(true, "exa")
	now := time.Now()
	snap, err := decodeSnapshot([]byte(liveSnapshot))
	if err != nil {
		t.Fatal(err)
	}
	ui.SetSnapshot(snap, now)
	tiles, keys := ui.frame(now)
	if got := lineTexts(tiles[6]); !strings.HasPrefix(got, "#42|refine|! input") {
		t.Errorf("first session tile %q", got)
	}
	if got := lineTexts(tiles[8]); got != "MORE|+3|" {
		t.Errorf("overflow tile %q", got)
	}
	keys[6].tap()
	if ui.page != pageDetail || ui.detailPane != "%84" {
		t.Fatalf("tap on session: page %v pane %q", ui.page, ui.detailPane)
	}
	ui.page = pageMain
	ui.SetSnapshot(nil, now)
	tiles, _ = ui.frame(now)
	if got := lineTexts(tiles[5]); got != "AGENTS|no|daemon" {
		t.Errorf("no daemon tile %q", got)
	}
}

func TestVT1HighlightAndStream(t *testing.T) {
	ui := NewUI(true, "exa")
	now := time.Now()
	ui.SetStats(Stats{VT1OK: true, VT1: "greetd-autologin@gamescope.service", Stream: true}, now)
	tiles, _ := ui.frame(now)
	if tiles[11].Tint != cAccent || tiles[10].Tint == cAccent {
		t.Error("GAME should be the gold tile")
	}
	if !strings.Contains(lineTexts(tiles[11]), "live") {
		t.Error("streaming badge missing")
	}
}

func TestWrap(t *testing.T) {
	got := wrap("Claude Code refine ticket", 9, 2)
	if len(got) != 2 || got[0] != "Claude" || got[1] != "Code" {
		t.Errorf("got %q", got)
	}
}
