// deckd drives an Elgato Stream Deck Original V2 as the status panel and
// button box of a headless desktop. See docs/streamdeck.md.
//
//	deckd [-device PATH] [-ups NAME] [-dry-run]   run the panel
//	deckd splash booting|shutdown [-device PATH]   paint a splash and exit
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

const (
	defaultDevice = "/dev/streamdeck" // udev SYMLINK+="streamdeck"
	pollEvery     = 2 * time.Second
	brightFor     = 60 * time.Second
	brightHigh    = 100
	brightLow     = 15 // dim, never off: a glanceable panel is the point
)

var (
	devicePath = flag.String("device", defaultDevice, "hidraw node of the deck")
	upsName    = flag.String("ups", "exa", "NUT UPS name for upsc")
	dryRun     = flag.Bool("dry-run", false, "log action commands instead of running them; without a device, log tiles as text")
)

func main() {
	log.SetFlags(0) // journald stamps lines already
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "usage: deckd [flags]\n       deckd splash booting|shutdown [flags]\n\n")
		flag.PrintDefaults()
	}
	flag.Parse()
	args := flag.Args()

	var err error
	switch {
	case len(args) == 0:
		err = runPanel()
	case args[0] == "splash" && len(args) >= 2:
		// Flags may come after the subcommand too.
		if err := flag.CommandLine.Parse(args[2:]); err != nil {
			os.Exit(2)
		}
		err = runSplash(args[1])
	default:
		flag.Usage()
		os.Exit(2)
	}
	if err != nil {
		log.Printf("deckd: %v", err)
		os.Exit(1)
	}
}

func openDeck() (*Device, error) {
	path := *devicePath
	if path == defaultDevice {
		var err error
		if path, err = FindDevice(defaultDevice); err != nil {
			return nil, err
		}
	}
	d, err := OpenDevice(path)
	if err != nil {
		return nil, err
	}
	serial, _ := d.Serial()
	fw, _ := d.Firmware()
	log.Printf("deck %s: serial %q firmware %q", path, serial, fw)
	return d, nil
}

// splashTarget is the part of Device a splash needs; tests fake it.
type splashTarget interface {
	SetBrightness(pct int) error
	SetKeyImage(key int, jpeg []byte) error
}

// paintSplash draws a full-deck splash. It deliberately never resets the
// deck afterwards: on SIGTERM this is the last frame left on the panel.
func paintSplash(d splashTarget, which string) error {
	var keys [keyCount][]byte
	switch which {
	case "booting":
		keys = Splash("BOOTING", "headless · deckd starting", cAccent)
	case "shutdown":
		keys = Splash("SHUTTING DOWN", "deckd stopped", cSecondary)
	default:
		return fmt.Errorf("unknown splash %q (booting|shutdown)", which)
	}
	if err := d.SetBrightness(brightHigh); err != nil {
		return err
	}
	for k, img := range keys {
		if err := d.SetKeyImage(k, img); err != nil {
			return err
		}
	}
	return nil
}

func runSplash(which string) error {
	d, err := openDeck()
	if err != nil {
		return err
	}
	defer d.Close()
	return paintSplash(d, which)
}

// textDeck stands in for the hardware under -dry-run when no deck is
// reachable, so the pollers and pages can be exercised anywhere.
type textDeck struct{}

func (textDeck) SetKeyImage(k int, t Tile) {
	var parts []string
	for _, l := range t.Lines {
		if l.Text != "" {
			parts = append(parts, l.Text)
		}
	}
	log.Printf("key %2d: %s", k, strings.Join(parts, " | "))
}

func runPanel() error {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer stop()

	d, err := openDeck()
	if err != nil {
		if !*dryRun {
			return err
		}
		log.Printf("dry-run without a device (%v): logging tiles as text", err)
		d = nil
	} else {
		defer d.Close()
		if err := d.Reset(); err != nil {
			return fmt.Errorf("reset: %w", err)
		}
	}
	if *dryRun {
		log.Printf("dry-run: action commands are logged, not run")
	}

	ui := NewUI(*dryRun, *upsName)

	keysCh := make(chan [keyCount]bool)
	readErr := make(chan error, 1)
	if d != nil {
		go func() {
			for {
				k, err := d.ReadKeys()
				if err != nil {
					readErr <- err
					return
				}
				keysCh <- k
			}
		}()
	}

	statsCh := make(chan Stats)
	go func() {
		p := &Poller{upsName: *upsName}
		for {
			s := p.Poll(ctx)
			select {
			case statsCh <- s:
			case <-ctx.Done():
				return
			}
			select {
			case <-time.After(pollEvery):
			case <-ctx.Done():
				return
			}
		}
	}()

	snapCh := make(chan *Snapshot)
	go watchCenci(ctx, cenciSocket(), snapCh)

	var (
		tracker   pressTracker
		shown     [keyCount]Tile
		painted   [keyCount]bool
		bright    = true
		lastPress = time.Now()
	)
	if d != nil {
		if err := d.SetBrightness(brightHigh); err != nil {
			return err
		}
	}
	repaint := func(now time.Time) error {
		tiles, _ := ui.frame(now)
		for k, t := range tiles {
			if painted[k] && t == shown[k] {
				continue
			}
			if d == nil {
				textDeck{}.SetKeyImage(k, t)
			} else if err := d.SetKeyImage(k, EncodeKey(Render(t))); err != nil {
				return err
			}
			shown[k], painted[k] = t, true
		}
		return nil
	}

	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()
	for {
		now := time.Now()
		select {
		case <-ctx.Done():
			// No ExecStop in the unit: the daemon owns the last frame.
			log.Printf("deckd: stopping")
			if d != nil {
				if err := paintSplash(d, "shutdown"); err != nil {
					log.Printf("deckd: shutdown splash: %v", err)
				}
			}
			return nil
		case err := <-readErr:
			return fmt.Errorf("read keys (unplugged?): %w", err)
		case k := <-keysCh:
			lastPress = now
			if !bright && d != nil {
				if err := d.SetBrightness(brightHigh); err != nil {
					return err
				}
			}
			bright = true
			for _, p := range tracker.Update(k, now) {
				ui.Press(p, now)
			}
		case s := <-statsCh:
			ui.SetStats(s, now)
		case snap := <-snapCh:
			ui.SetSnapshot(snap, now)
		case <-ticker.C:
			for _, p := range tracker.Poll(now) {
				ui.Press(p, now)
			}
			ui.Tick(now)
			if bright && now.Sub(lastPress) > brightFor {
				bright = false
				if d != nil {
					if err := d.SetBrightness(brightLow); err != nil {
						return err
					}
				}
			}
		}
		if err := repaint(now); err != nil {
			return fmt.Errorf("write: %w", err)
		}
	}
}
