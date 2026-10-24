package main

// Row 1 probes. Each one is time-boxed and reports failure as ok=false, so a
// hung tool costs one stale tile, never the tick.

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

const probeTimeout = time.Second

// tool resolves a system binary even under a unit's minimal PATH.
func tool(name string) string {
	if p, err := exec.LookPath(name); err == nil {
		return p
	}
	return "/usr/bin/" + name
}

// userTool resolves something installed into ~/.local/bin.
func userTool(name string) string {
	return filepath.Join(os.Getenv("HOME"), ".local", "bin", name)
}

// childEnv gives spawned tools a sane PATH: `desktop` calls systemctl and sed,
// `cenci` calls tmux.
func childEnv() []string {
	path := userTool("") + ":/usr/local/bin:/usr/bin:/bin"
	if p := os.Getenv("PATH"); p != "" {
		path += ":" + p
	}
	env := []string{"PATH=" + path}
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, "PATH=") {
			env = append(env, kv)
		}
	}
	return env
}

func probe(ctx context.Context, name string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, probeTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = childEnv()
	out, err := cmd.Output()
	// systemctl is-active exits non-zero when any unit is inactive; the
	// output is still what we want.
	var exit *exec.ExitError
	if errors.As(err, &exit) && len(out) > 0 && ctx.Err() == nil {
		err = nil
	}
	return string(out), err
}

// --- CPU ---

type cpuTimes struct{ idle, total uint64 }

func parseProcStat(s string) (cpuTimes, error) {
	line, _, _ := strings.Cut(s, "\n")
	f := strings.Fields(line)
	if len(f) < 5 || f[0] != "cpu" {
		return cpuTimes{}, fmt.Errorf("bad /proc/stat line %q", line)
	}
	// user nice system idle iowait irq softirq steal [guest guest_nice];
	// guest time is already counted in user, so only the first eight add up.
	var t cpuTimes
	for i, v := range f[1:min(len(f), 9)] {
		n, err := strconv.ParseUint(v, 10, 64)
		if err != nil {
			return cpuTimes{}, err
		}
		t.total += n
		if i == 3 || i == 4 { // idle, iowait
			t.idle += n
		}
	}
	return t, nil
}

func cpuPercent(prev, cur cpuTimes) float64 {
	dt := float64(cur.total - prev.total)
	if dt <= 0 || cur.total < prev.total {
		return 0
	}
	return 100 * (1 - float64(cur.idle-prev.idle)/dt)
}

func readLoad() (float64, error) {
	b, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return 0, err
	}
	f := strings.Fields(string(b))
	if len(f) == 0 {
		return 0, errors.New("empty loadavg")
	}
	return strconv.ParseFloat(f[0], 64)
}

// cpuTemp is k10temp's Tctl, found by hwmon name (the index moves per boot).
func cpuTemp() (float64, error) {
	names, _ := filepath.Glob("/sys/class/hwmon/hwmon*/name")
	for _, n := range names {
		b, err := os.ReadFile(n)
		if err != nil || strings.TrimSpace(string(b)) != "k10temp" {
			continue
		}
		v, err := os.ReadFile(filepath.Join(filepath.Dir(n), "temp1_input"))
		if err != nil {
			return 0, err
		}
		milli, err := strconv.Atoi(strings.TrimSpace(string(v)))
		return float64(milli) / 1000, err
	}
	return 0, errors.New("no k10temp")
}

// --- RAM ---

// parseMeminfo returns used and total bytes (used = total - available).
func parseMeminfo(s string) (used, total uint64, err error) {
	var avail uint64
	var haveT, haveA bool
	sc := bufio.NewScanner(strings.NewReader(s))
	for sc.Scan() {
		f := strings.Fields(sc.Text())
		if len(f) < 2 {
			continue
		}
		n, perr := strconv.ParseUint(f[1], 10, 64)
		if perr != nil {
			continue
		}
		switch f[0] {
		case "MemTotal:":
			total, haveT = n*1024, true
		case "MemAvailable:":
			avail, haveA = n*1024, true
		}
	}
	if !haveT || !haveA {
		return 0, 0, errors.New("meminfo: MemTotal/MemAvailable missing")
	}
	return total - avail, total, nil
}

// --- GPU ---

type GPU struct {
	Util, Temp int
	Power      float64
}

func parseNvidia(s string) (GPU, error) {
	line, _, _ := strings.Cut(strings.TrimSpace(s), "\n")
	f := strings.Split(line, ",")
	if len(f) != 3 {
		return GPU{}, fmt.Errorf("nvidia-smi: unexpected %q", line)
	}
	var g GPU
	var err1, err2, err3 error
	g.Util, err1 = strconv.Atoi(strings.TrimSpace(f[0]))
	g.Temp, err2 = strconv.Atoi(strings.TrimSpace(f[1]))
	g.Power, err3 = strconv.ParseFloat(strings.TrimSpace(f[2]), 64)
	return g, errors.Join(err1, err2, err3)
}

// --- UPS ---

type UPS struct {
	Status  string // e.g. "OL", "OB DISCHRG", "OL CHRG"
	Charge  int    // %
	Runtime int    // seconds
	Load    int    // %
}

func (u UPS) OnBattery() bool {
	for _, f := range strings.Fields(u.Status) {
		if f == "OB" {
			return true
		}
	}
	return false
}

func parseUpsc(s string) (UPS, error) {
	kv := map[string]string{}
	for _, line := range strings.Split(s, "\n") {
		if k, v, ok := strings.Cut(line, ":"); ok {
			kv[strings.TrimSpace(k)] = strings.TrimSpace(v)
		}
	}
	u := UPS{Status: kv["ups.status"]}
	if u.Status == "" {
		return u, errors.New("upsc: no ups.status")
	}
	num := func(k string) int {
		f, _ := strconv.ParseFloat(kv[k], 64)
		return int(f)
	}
	u.Charge, u.Runtime, u.Load = num("battery.charge"), num("battery.runtime"), num("ups.load")
	return u, nil
}

// --- NET ---

type Net struct {
	Runners, RunnersTotal int
	RunnersOK             bool
	SSH                   int
	SSHOK                 bool
	Docker                int
	DockerOK              bool
	DiskFree              uint64
	DiskOK                bool
}

func countLines(s string) int {
	n := 0
	for _, l := range strings.Split(s, "\n") {
		if strings.TrimSpace(l) != "" {
			n++
		}
	}
	return n
}

// runnerUnit matches the system units `svc.sh install` creates for each
// self-hosted GitHub Actions runner.
const runnerUnit = "actions.runner.*"

// parseRunners counts `systemctl list-units --all --plain --no-legend` rows
// (UNIT LOAD ACTIVE SUB DESCRIPTION): active ones out of all of them.
func parseRunners(out string) (active, total int) {
	for _, l := range strings.Split(out, "\n") {
		f := strings.Fields(l)
		if len(f) < 3 {
			continue
		}
		total++
		if f[2] == "active" {
			active++
		}
	}
	return active, total
}

// --- vt1 ---

var vt1Units = []string{
	"greetd.service",
	"greetd-autologin@niri.service",
	"greetd-autologin@gamescope.service",
}

// parseIsActive maps `systemctl is-active u1 u2 …` output to the unit that
// owns vt1, or "" when none does (getty).
func parseIsActive(out string, units []string) string {
	lines := strings.Split(strings.TrimSpace(out), "\n")
	for i, l := range lines {
		if i < len(units) && (l == "active" || l == "activating" || l == "reloading") {
			return units[i]
		}
	}
	return ""
}

// --- the 2 s snapshot ---

type Stats struct {
	CPU      float64
	CPUOK    bool
	Load     float64
	LoadOK   bool
	Temp     float64
	TempOK   bool
	MemUsed  uint64
	MemTotal uint64
	MemOK    bool
	GPU      GPU
	GPUOK    bool
	UPS      UPS
	UPSOK    bool
	Net      Net
	VT1      string
	VT1OK    bool
	Stream   bool
}

type Poller struct {
	upsName string
	prevCPU cpuTimes
}

// Poll runs every probe concurrently and waits at most ~probeTimeout.
func (p *Poller) Poll(ctx context.Context) Stats {
	var s Stats
	var mu sync.Mutex
	var wg sync.WaitGroup
	set := func(f func()) { mu.Lock(); f(); mu.Unlock() }
	run := func(f func()) { wg.Add(1); go func() { defer wg.Done(); f() }() }

	if b, err := os.ReadFile("/proc/stat"); err == nil {
		if cur, err := parseProcStat(string(b)); err == nil {
			if p.prevCPU.total != 0 {
				s.CPU, s.CPUOK = cpuPercent(p.prevCPU, cur), true
			}
			p.prevCPU = cur
		}
	}
	if l, err := readLoad(); err == nil {
		s.Load, s.LoadOK = l, true
	}
	if t, err := cpuTemp(); err == nil {
		s.Temp, s.TempOK = t, true
	}
	if b, err := os.ReadFile("/proc/meminfo"); err == nil {
		if u, t, err := parseMeminfo(string(b)); err == nil {
			s.MemUsed, s.MemTotal, s.MemOK = u, t, true
		}
	}
	var fs syscall.Statfs_t
	if err := syscall.Statfs("/", &fs); err == nil {
		s.Net.DiskFree, s.Net.DiskOK = fs.Bavail*uint64(fs.Bsize), true
	}
	if _, err := os.Stat(fmt.Sprintf("/run/user/%d/sunshine-stream-prep.desk-off", os.Getuid())); err == nil {
		s.Stream = true
	}

	run(func() {
		out, err := probe(ctx, tool("nvidia-smi"), "--query-gpu=utilization.gpu,temperature.gpu,power.draw", "--format=csv,noheader,nounits")
		if err == nil {
			if g, err := parseNvidia(out); err == nil {
				set(func() { s.GPU, s.GPUOK = g, true })
			}
		}
	})
	run(func() {
		out, err := probe(ctx, tool("upsc"), p.upsName)
		if err == nil {
			if u, err := parseUpsc(out); err == nil {
				set(func() { s.UPS, s.UPSOK = u, true })
			}
		}
	})
	run(func() {
		out, err := probe(ctx, tool("systemctl"), append([]string{"is-active"}, vt1Units...)...)
		if err == nil {
			set(func() { s.VT1, s.VT1OK = parseIsActive(out, vt1Units), true })
		}
	})
	run(func() {
		out, err := probe(ctx, tool("systemctl"), "list-units", "--all", "--plain", "--no-legend", "--type=service", runnerUnit)
		if err == nil {
			a, t := parseRunners(out)
			set(func() { s.Net.Runners, s.Net.RunnersTotal, s.Net.RunnersOK = a, t, true })
		}
	})
	run(func() {
		out, err := probe(ctx, tool("ss"), "-Htn", "state", "established", "( sport = :22 )")
		if err == nil {
			set(func() { s.Net.SSH, s.Net.SSHOK = countLines(out), true })
		}
	})
	run(func() {
		out, err := probe(ctx, tool("docker"), "ps", "-q")
		if err == nil {
			set(func() { s.Net.Docker, s.Net.DockerOK = countLines(out), true })
		}
	})
	wg.Wait()
	return s
}
