package main

// Pages, tiles and what each key does. Everything here runs on the main
// loop's goroutine; frame() is pure apart from reading UI state.

import (
	"context"
	"fmt"
	"image/color"
	"log"
	"os/exec"
	"strings"
	"time"
)

const (
	holdTime      = 1500 * time.Millisecond
	upsGrace      = 300 * time.Second // upssched's ONBATT timer, docs/ups.md
	powerTimeout  = 15 * time.Second  // confirm page cancels itself
	pendingShown  = 5 * time.Second   // "…" after an action key
	actionTimeout = 60 * time.Second
)

// --- press classification ---

type pressKind int

const (
	tap pressKind = iota + 1
	hold
)

type press struct {
	key  int
	kind pressKind
}

// pressTracker turns key-state reports into taps and holds. A hold fires
// once, as soon as the key has been down for holdTime (via Poll), or on
// release if no Poll caught it first; a release before holdTime is a tap.
type pressTracker struct {
	down  [keyCount]time.Time
	fired [keyCount]bool
	state [keyCount]bool
}

func (p *pressTracker) Update(keys [keyCount]bool, now time.Time) []press {
	var out []press
	for k, isDown := range keys {
		if isDown == p.state[k] {
			continue
		}
		p.state[k] = isDown
		if isDown {
			p.down[k], p.fired[k] = now, false
			continue
		}
		if !p.fired[k] {
			kind := tap
			if now.Sub(p.down[k]) >= holdTime {
				kind = hold
			}
			out = append(out, press{k, kind})
		}
	}
	return out
}

func (p *pressTracker) Poll(now time.Time) []press {
	var out []press
	for k := range p.state {
		if p.state[k] && !p.fired[k] && now.Sub(p.down[k]) >= holdTime {
			p.fired[k] = true
			out = append(out, press{k, hold})
		}
	}
	return out
}

// --- UI state ---

type page int

const (
	pageMain page = iota
	pageAgents
	pageDetail
	pagePower
)

type keyAction struct {
	tap, hold func()
}

type statusSince struct {
	status string
	since  time.Time
}

type UI struct {
	dryRun  bool
	upsName string

	stats     Stats
	haveStats bool
	snap      *Snapshot
	since     map[string]statusSince // pane id -> when it entered its status

	page        page
	detailPane  string
	powerOpened time.Time
	netMode     int

	obSince      time.Time
	upsDismissed bool

	pending [keyCount]time.Time
}

func NewUI(dryRun bool, upsName string) *UI {
	return &UI{dryRun: dryRun, upsName: upsName, since: map[string]statusSince{}}
}

func (u *UI) SetStats(s Stats, now time.Time) {
	u.stats, u.haveStats = s, true
	if !s.UPSOK {
		return // upsc failing mid-outage must not cancel the takeover
	}
	if s.UPS.OnBattery() {
		if u.obSince.IsZero() {
			log.Printf("ups: on battery (%s)", s.UPS.Status)
			u.obSince, u.upsDismissed = now, false
		}
	} else if !u.obSince.IsZero() {
		log.Printf("ups: back on line (%s)", s.UPS.Status)
		u.obSince, u.upsDismissed = time.Time{}, false
	}
}

func (u *UI) SetSnapshot(s *Snapshot, now time.Time) {
	u.snap = s
	if s == nil {
		return
	}
	seen := map[string]bool{}
	for _, w := range s.Windows {
		seen[w.PaneID] = true
		if old, ok := u.since[w.PaneID]; !ok || old.status != w.Status {
			u.since[w.PaneID] = statusSince{w.Status, now}
		}
	}
	for id := range u.since {
		if !seen[id] {
			delete(u.since, id)
		}
	}
}

func (u *UI) takeover() bool { return !u.obSince.IsZero() && !u.upsDismissed }

// Press dispatches a classified press against the frame currently shown.
// A hold on a key with no hold action counts as a tap.
func (u *UI) Press(p press, now time.Time) {
	_, keys := u.frame(now)
	a := keys[p.key]
	f := a.tap
	if p.kind == hold && a.hold != nil {
		f = a.hold
	}
	if f != nil {
		f()
	}
}

// Tick handles timeouts that do not depend on input.
func (u *UI) Tick(now time.Time) {
	if u.page == pagePower && now.Sub(u.powerOpened) > powerTimeout {
		u.page = pageMain
	}
}

// run executes an action command, or only logs it under -dry-run.
func (u *UI) run(name string, args ...string) {
	line := strings.TrimSpace(name + " " + strings.Join(args, " "))
	if u.dryRun {
		log.Printf("dry-run: would run: %s", line)
		return
	}
	log.Printf("run: %s", line)
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), actionTimeout)
		defer cancel()
		cmd := exec.CommandContext(ctx, name, args...)
		cmd.Env = childEnv()
		out, err := cmd.CombinedOutput()
		if s := strings.TrimSpace(string(out)); s != "" {
			log.Printf("%s: %s", line, s)
		}
		if err != nil {
			log.Printf("%s: %v", line, err)
		}
	}()
}

// --- frames ---

func (u *UI) frame(now time.Time) (tiles [keyCount]Tile, keys [keyCount]keyAction) {
	switch {
	case u.takeover():
		u.upsPage(now, &tiles, &keys)
	case u.page == pagePower:
		u.powerPage(&tiles, &keys)
	case u.page == pageAgents:
		u.agentsPage(now, &tiles, &keys)
	case u.page == pageDetail:
		u.detailPage(now, &tiles, &keys)
	default:
		u.statsRow(&tiles, &keys)
		u.agentsRow(now, &tiles, &keys)
		u.actionsRow(now, &tiles, &keys)
	}
	return
}

const dash = "—"

func pctColor(p float64) color.RGBA {
	switch {
	case p >= 90:
		return cUrgent
	case p >= 70:
		return cWarning
	}
	return cSuccess
}

func human(b uint64) string {
	g := float64(b) / (1 << 30)
	switch {
	case g >= 1000:
		return fmt.Sprintf("%.1fT", g/1024)
	case g >= 10:
		return fmt.Sprintf("%.0fG", g)
	}
	return fmt.Sprintf("%.1fG", g)
}

func (u *UI) statsRow(t *[keyCount]Tile, k *[keyCount]keyAction) {
	s := u.stats

	cpu := tile(label("CPU"), big(dash, cDisabled), note(dash, cSecondary))
	if s.CPUOK {
		cpu.Lines[1] = big(fmt.Sprintf("%.0f%%", s.CPU), pctColor(s.CPU))
		cpu.Tint, cpu.Gauge = pctColor(s.CPU), s.CPU/100
	}
	var sub []string
	if s.LoadOK {
		sub = append(sub, fmt.Sprintf("%.1f", s.Load))
	}
	if s.TempOK {
		sub = append(sub, fmt.Sprintf("%.0f°", s.Temp))
	}
	if len(sub) > 0 {
		cpu.Lines[2] = note(strings.Join(sub, " · "), cSecondary)
	}
	t[0] = cpu

	ram := tile(label("RAM"), mid(dash, cDisabled))
	if s.MemOK {
		p := 100 * float64(s.MemUsed) / float64(s.MemTotal)
		ram.Lines[1] = mid(strings.TrimSuffix(human(s.MemUsed), "G")+"/"+human(s.MemTotal), pctColor(p))
		ram.Lines[2] = note(fmt.Sprintf("%.0f%%", p), cSecondary)
		ram.Tint, ram.Gauge = pctColor(p), p/100
	}
	t[1] = ram

	gpu := tile(label("GPU"), mid(dash, cDisabled))
	if s.GPUOK {
		gpu.Lines[1] = mid(fmt.Sprintf("%d%% %d°", s.GPU.Util, s.GPU.Temp), pctColor(float64(s.GPU.Util)))
		gpu.Lines[2] = note(fmt.Sprintf("%.0f W", s.GPU.Power), cSecondary)
		gpu.Tint, gpu.Gauge = pctColor(float64(s.GPU.Util)), float64(s.GPU.Util)/100
	}
	t[2] = gpu

	ups := tile(label("UPS"), mid(dash, cDisabled))
	if s.UPSOK {
		c := cSuccess
		if s.UPS.OnBattery() {
			c = cUrgent
			ups.Border = cUrgent
		}
		status, _, _ := strings.Cut(s.UPS.Status, " ")
		ups.Lines[1] = mid(fmt.Sprintf("%s %d%%", status, s.UPS.Charge), c)
		ups.Lines[2] = note(fmt.Sprintf("%d min", s.UPS.Runtime/60), cSecondary)
		ups.Tint, ups.Gauge = c, float64(s.UPS.Charge)/100
	}
	t[3] = ups
	k[3].tap = func() { u.upsDismissed = false } // reopen the takeover while OB

	t[4] = u.netTile()
	k[4].tap = func() { u.netMode = (u.netMode + 1) % 4 }
}

func (u *UI) netTile() Tile {
	n := u.stats.Net
	dots := []rune("○○○○")
	dots[u.netMode] = '●'
	val, c := dash, cDisabled
	var name string
	switch u.netMode {
	case 0:
		name = "TAILSCALE"
		if n.TailscaleOK {
			val, c = "off", cUrgent
			if n.Tailscale {
				val, c = "on", cSuccess
			}
		}
	case 1:
		name = "SSH"
		if n.SSHOK {
			val, c = fmt.Sprint(n.SSH), cText
		}
	case 2:
		name = "DOCKER"
		if n.DockerOK {
			val, c = fmt.Sprint(n.Docker), cText
		}
	case 3:
		name = "DISK FREE"
		if n.DiskOK {
			val, c = human(n.DiskFree), cText
			if n.DiskFree < 20<<30 {
				c = cWarning
			}
		}
	}
	t := tile(label(name), big(val, c), note(string(dots), cSecondary))
	t.Tint = cInfo
	if c == cUrgent || c == cWarning {
		t.Tint = c
	}
	return t
}

type statusStyle struct {
	text  string
	color color.RGBA
}

func styleFor(status string) statusStyle {
	switch status {
	case "need_input":
		return statusStyle{"! input", cUrgent}
	case "failed":
		return statusStyle{"✗ failed", cUrgent}
	case "escalated":
		return statusStyle{"▲ escal", cWarning}
	case "running":
		return statusStyle{"▶ run", cInfo}
	case "done":
		return statusStyle{"✓ done", cSuccess}
	case "stopped":
		return statusStyle{"■ stop", cSecondary}
	case "idle":
		return statusStyle{"· idle", cSecondary}
	}
	return statusStyle{status, cSecondary}
}

func sessionTile(w Window) Tile {
	head, rest := shortName(w.WindowName)
	st := styleFor(w.Status)
	t := tile(mid(head, cText), note(rest, cSecondary), Line{st.text, small, true, st.color})
	t.Tint = st.color
	if w.Status == "need_input" || w.Status == "failed" {
		t.Border = cWhite
	}
	return t
}

// sessionKeys: tap opens the detail page, hold on a done session reaps it.
func (u *UI) sessionKeys(w Window) keyAction {
	a := keyAction{tap: func() { u.page, u.detailPane = pageDetail, w.PaneID }}
	if w.Status == "done" {
		a.hold = func() { u.run(userTool("cenci"), "close", w.WindowName) }
	} else {
		a.hold = func() {} // a hold must never fall through to a tap here
	}
	return a
}

// agentsRow is one count per state, nothing else: what is running, what is
// waiting on you, what broke, what finished, what sits idle. A tap on any of
// them opens the agents page, which lists the sessions themselves.
func (u *UI) agentsRow(now time.Time, t *[keyCount]Tile, k *[keyCount]keyAction) {
	s := u.snap
	if s == nil {
		t[5] = tile(label("AGENTS"), mid("no", cDisabled), mid("daemon", cDisabled))
		return
	}
	sum := s.Summary
	counts := []struct {
		name string
		n    int
		tint color.RGBA
	}{
		{"RUNNING", sum.Running, cInfo},
		{"INPUT", sum.NeedInput + sum.Escalated, cWarning},
		{"FAILED", sum.Failed, cUrgent},
		{"DONE", sum.Done, cSuccess},
		{"IDLE", sum.Idle + sum.Stopped, cSecondary},
	}
	for i, c := range counts {
		tl := tile(label(c.name), big(fmt.Sprint(c.n), cText))
		if c.n > 0 {
			tl.Tint = c.tint
		} else {
			tl.Lines[1].Color = cDisabled
		}
		t[5+i] = tl
		k[5+i].tap = func() { u.page = pageAgents }
	}
}

func (u *UI) actionsRow(now time.Time, t *[keyCount]Tile, k *[keyCount]keyAction) {
	s := u.stats
	act := func(key int, name, unit string, tint color.RGBA, args ...string) {
		on := s.VT1OK && s.VT1 == unit
		tl := tile(mid(name, cText), note("○", cSecondary))
		tl.Tint = tint
		if on {
			tl.Lines[1] = note("● on", cText)
			tl.Tint = cAccent
			tl.Fill = mix(cBG, cAccent, 0.75)
			tl.Border = cWhite
		}
		if now.Sub(u.pending[key]) < pendingShown {
			tl.Lines[1] = note("…", cAccent)
		}
		t[key] = tl
		k[key].tap = func() {
			u.pending[key] = now
			u.run(userTool("desktop"), args...)
		}
	}
	act(10, "NIRI", "greetd-autologin@niri.service", cInfo, "up", "niri")
	act(11, "GAME", "greetd-autologin@gamescope.service", cMagenta, "up", "gamescope")
	act(12, "GREETER", "greetd.service", cCyan, "greeter")
	act(13, "DOWN", "", cSecondary, "down")
	if s.VT1OK && s.VT1 == "" && now.Sub(u.pending[13]) >= pendingShown {
		t[13].Lines[1] = note("● tty", cText)
		t[13].Tint = cAccent
		t[13].Fill = mix(cBG, cAccent, 0.75)
		t[13].Border = cWhite
	}
	if s.Stream {
		t[11].Lines[2] = Line{"● live", small, true, cUrgent}
	}

	t[14] = tile(big("⏻", cText), note("hold", cSecondary))
	t[14].Tint = cUrgent
	k[14].hold = func() { u.page, u.powerOpened = pagePower, now }
	k[14].tap = func() {}
}

func backKey(t *Tile, a *keyAction, to func()) {
	*t = tile(mid("‹", cSecondary), note("BACK", cSecondary))
	a.tap = to
}

func (u *UI) agentsPage(now time.Time, t *[keyCount]Tile, k *[keyCount]keyAction) {
	backKey(&t[14], &k[14], func() { u.page = pageMain })
	if u.snap == nil {
		t[0] = tile(label("AGENTS"), mid("no", cDisabled), mid("daemon", cDisabled))
		return
	}
	ws := u.snap.Windows
	for i, w := range ws {
		if i == 13 && len(ws) > 14 {
			t[13] = tile(label("MORE"), big(fmt.Sprintf("+%d", len(ws)-13), cSecondary))
			break
		}
		t[i] = sessionTile(w)
		k[i] = u.sessionKeys(w)
	}
}

// wrap breaks s into at most n lines of width runes.
func wrap(s string, width, n int) []string {
	var lines []string
	cur := ""
	for _, word := range strings.Fields(s) {
		switch {
		case cur == "":
			cur = word
		case len([]rune(cur))+1+len([]rune(word)) <= width:
			cur += " " + word
		default:
			lines = append(lines, cur)
			cur = word
		}
	}
	if cur != "" {
		lines = append(lines, cur)
	}
	if len(lines) > n {
		lines = lines[:n]
	}
	return lines
}

func ago(d time.Duration) string {
	switch {
	case d < time.Minute:
		return fmt.Sprintf("%ds", int(d.Seconds()))
	case d < time.Hour:
		return fmt.Sprintf("%dm", int(d.Minutes()))
	}
	return fmt.Sprintf("%dh%02dm", int(d.Hours()), int(d.Minutes())%60)
}

func (u *UI) detailPage(now time.Time, t *[keyCount]Tile, k *[keyCount]keyAction) {
	backKey(&t[10], &k[10], func() { u.page = pageMain })
	var w *Window
	if u.snap != nil {
		for i := range u.snap.Windows {
			if u.snap.Windows[i].PaneID == u.detailPane {
				w = &u.snap.Windows[i]
			}
		}
	}
	if w == nil {
		t[0] = tile(label("SESSION"), mid("gone", cDisabled))
		return
	}
	head, rest := shortName(w.WindowName)
	t[0] = tile(big(head, cAccent), note(rest, cSecondary))
	task := wrap(w.TaskName, 9, 2)
	t[1] = tile(label("TASK"))
	for i, l := range task {
		t[1].Lines[1+i] = note(l, cText)
	}
	t[2] = tile(label("AGENT"), mid(w.Agent, cText))
	t[3] = tile(label("WINDOW"), mid(w.Session, cText), note(":"+w.WindowIndex, cSecondary))
	st := styleFor(w.Status)
	t[4] = tile(label("STATUS"), Line{st.text, medium, true, st.color})
	if s, ok := u.since[w.PaneID]; ok {
		t[4].Lines[2] = note(ago(now.Sub(s.since)), cSecondary)
	}
	if w.Status == "done" {
		t[14] = tile(mid("CLOSE", cUrgent), note("hold", cSecondary))
		name := w.WindowName
		k[14].hold = func() {
			u.run(userTool("cenci"), "close", name)
			u.page = pageMain
		}
		k[14].tap = func() {}
	}
}

func (u *UI) powerPage(t *[keyCount]Tile, k *[keyCount]keyAction) {
	t[2] = tile(label("POWER"), mid("press one", cSecondary))
	t[6] = tile(mid("REBOOT", cWarning), note("press", cSecondary))
	t[6].Border = cWarning
	k[6].tap = func() { u.run(tool("systemctl"), "reboot") }
	t[8] = tile(mid("POWER", cUrgent), mid("OFF", cUrgent))
	t[8].Border = cUrgent
	k[8].tap = func() { u.run(tool("systemctl"), "poweroff") }
	backKey(&t[12], &k[12], func() { u.page = pageMain })
	t[12].Lines[1] = note("CANCEL", cSecondary)
}

func (u *UI) upsPage(now time.Time, t *[keyCount]Tile, k *[keyCount]keyAction) {
	s := u.stats.UPS
	t[0] = tile(label("UPS"), big("OB", cUrgent), note("battery", cUrgent))
	t[0].Border = cUrgent
	t[1] = tile(label("CHARGE"), big(fmt.Sprintf("%d%%", s.Charge), cText))
	t[2] = tile(label("RUNTIME"), big(fmt.Sprintf("%dm", s.Runtime/60), cText))
	t[3] = tile(label("LOAD"), big(fmt.Sprintf("%d%%", s.Load), cText))
	left := upsGrace - now.Sub(u.obSince)
	cd := "now"
	if left > 0 {
		secs := int(left.Round(time.Second).Seconds())
		cd = fmt.Sprintf("%d:%02d", secs/60, secs%60)
	}
	t[4] = tile(label("SHUTDOWN"), big(cd, cUrgent), note("upssched", cSecondary))
	t[7] = tile(note(s.Status, cSecondary))

	backKey(&t[10], &k[10], func() { u.upsDismissed = true })
	t[10].Lines[1] = note("VIEW", cSecondary)
	t[14] = tile(big("⏻", cUrgent), note("hold: off", cSecondary))
	k[14].hold = func() { u.run(tool("systemctl"), "poweroff") }
	k[14].tap = func() {}
}
