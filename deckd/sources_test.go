package main

import (
	"math"
	"testing"
)

func TestParseProcStat(t *testing.T) {
	prev, err := parseProcStat("cpu  100 0 100 700 100 0 0 0 50 0\ncpu0 1 2 3 4\n")
	if err != nil {
		t.Fatal(err)
	}
	if prev.total != 1000 || prev.idle != 800 {
		t.Fatalf("prev = %+v (guest must not be double counted)", prev)
	}
	cur, _ := parseProcStat("cpu  300 0 200 1300 200 0 0 0 0 0")
	if got := cpuPercent(prev, cur); math.Abs(got-30) > 0.01 {
		t.Errorf("cpu%% = %v, want 30", got)
	}
	if _, err := parseProcStat("intr 1 2 3"); err == nil {
		t.Error("want error for non-cpu line")
	}
	if got := cpuPercent(cur, cur); got != 0 {
		t.Errorf("no elapsed time: got %v", got)
	}
}

func TestParseMeminfo(t *testing.T) {
	used, total, err := parseMeminfo("MemTotal:       65000000 kB\nMemFree:  1000 kB\nMemAvailable:   40000000 kB\n")
	if err != nil {
		t.Fatal(err)
	}
	if total != 65000000*1024 || used != 25000000*1024 {
		t.Errorf("used %d total %d", used, total)
	}
	if _, _, err := parseMeminfo("MemTotal: 1 kB\n"); err == nil {
		t.Error("missing MemAvailable: want error")
	}
}

func TestParseNvidia(t *testing.T) {
	g, err := parseNvidia("4, 41, 12.34\n")
	if err != nil || g.Util != 4 || g.Temp != 41 || g.Power != 12.34 {
		t.Errorf("got %+v, %v", g, err)
	}
	if _, err := parseNvidia("[N/A], 41, 12.3"); err == nil {
		t.Error("N/A util: want error")
	}
	if _, err := parseNvidia("NVIDIA-SMI has failed"); err == nil {
		t.Error("garbage: want error")
	}
}

func TestParseUpsc(t *testing.T) {
	out := "battery.charge: 84\nbattery.runtime: 2280\ndevice.mfr: Tecnoware\nups.load: 23\nups.status: OB DISCHRG\n"
	u, err := parseUpsc(out)
	if err != nil {
		t.Fatal(err)
	}
	if u.Charge != 84 || u.Runtime != 2280 || u.Load != 23 || !u.OnBattery() {
		t.Errorf("got %+v", u)
	}
	if (UPS{Status: "OL CHRG"}).OnBattery() {
		t.Error("OL CHRG is not on battery")
	}
	if _, err := parseUpsc("Error: Connection failure: Connection refused\n"); err == nil {
		t.Error("no ups.status: want error")
	}
}

func TestParseIsActive(t *testing.T) {
	if got := parseIsActive("inactive\nactive\ninactive\n", vt1Units); got != "greetd-autologin@niri.service" {
		t.Errorf("got %q", got)
	}
	if got := parseIsActive("inactive\ninactive\ninactive\n", vt1Units); got != "" {
		t.Errorf("got %q, want getty (empty)", got)
	}
}

func TestTailscaleAndCount(t *testing.T) {
	on, err := tailscaleOnline(`{"Version":"1","BackendState":"Running"}`)
	if err != nil || !on {
		t.Errorf("running: %v %v", on, err)
	}
	if on, _ := tailscaleOnline(`{"BackendState":"Stopped"}`); on {
		t.Error("stopped reported online")
	}
	if n := countLines("abc\ndef\n\n"); n != 2 {
		t.Errorf("countLines = %d", n)
	}
}
