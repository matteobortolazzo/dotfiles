package main

// Elgato Stream Deck Original V2 (0fd9:006d) over Linux hidraw, no cgo.
// Ported from python-elgato-streamdeck's StreamDeckOriginalV2.

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"unsafe"
)

const (
	keyCount   = 15
	keyCols    = 5
	keyPixels  = 72
	reportLen  = 1024
	headerLen  = 8
	payloadLen = reportLen - headerLen
	featureLen = 32
	keyOffset  = 4 // key bytes start here in an input report

	hidID = "HID_ID=0003:00000FD9:0000006D"
)

// Device is an open Stream Deck. Writes are serialised; reads happen on
// whatever goroutine calls ReadKeys.
type Device struct {
	f  *os.File
	mu sync.Mutex
}

// FindDevice returns the hidraw node for the deck: the udev symlink if it
// exists, otherwise the first hidraw whose sysfs uevent carries our HID_ID.
func FindDevice(symlink string) (string, error) {
	if _, err := os.Stat(symlink); err == nil {
		return symlink, nil
	}
	nodes, _ := filepath.Glob("/sys/class/hidraw/*/device/uevent")
	for _, ue := range nodes {
		b, err := os.ReadFile(ue)
		if err != nil {
			continue
		}
		if strings.Contains(string(b), hidID) {
			name := filepath.Base(filepath.Dir(filepath.Dir(ue)))
			return "/dev/" + name, nil
		}
	}
	return "", fmt.Errorf("no Stream Deck found (%s missing, no hidraw with %s)", symlink, hidID)
}

func OpenDevice(path string) (*Device, error) {
	f, err := os.OpenFile(path, os.O_RDWR, 0)
	if err != nil {
		return nil, fmt.Errorf("%w (udev rule missing? no seat means no uaccess)", err)
	}
	d := &Device{f: f}
	// Same as the Python library's open(): flush any half-sent image.
	flush := make([]byte, reportLen)
	flush[0] = 0x02
	if err := d.write(flush); err != nil {
		f.Close()
		return nil, err
	}
	return d, nil
}

func (d *Device) Close() error { return d.f.Close() }

func (d *Device) write(b []byte) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	_, err := d.f.Write(b)
	return err
}

// imageReports splits a JPEG into the deck's 1024-byte output reports.
func imageReports(key int, img []byte) [][]byte {
	var out [][]byte
	for page, sent := 0, 0; sent < len(img); page++ {
		n := min(len(img)-sent, payloadLen)
		last := byte(0)
		if sent+n == len(img) {
			last = 1
		}
		r := make([]byte, reportLen)
		copy(r, []byte{0x02, 0x07, byte(key), last, byte(n), byte(n >> 8), byte(page), byte(page >> 8)})
		copy(r[headerLen:], img[sent:sent+n])
		out = append(out, r)
		sent += n
	}
	return out
}

// SetKeyImage sends an already flipped 72x72 JPEG to a key.
func (d *Device) SetKeyImage(key int, jpeg []byte) error {
	if key < 0 || key >= keyCount {
		return fmt.Errorf("key %d out of range", key)
	}
	for _, r := range imageReports(key, jpeg) {
		if err := d.write(r); err != nil {
			return fmt.Errorf("key %d: %w", key, err)
		}
	}
	return nil
}

// parseKeys reads the 15 key states out of an input report.
func parseKeys(report []byte) ([keyCount]bool, error) {
	var keys [keyCount]bool
	if len(report) < keyOffset+keyCount {
		return keys, fmt.Errorf("short input report: %d bytes", len(report))
	}
	for i := range keys {
		keys[i] = report[keyOffset+i] != 0
	}
	return keys, nil
}

// ReadKeys blocks until the next input report. Any error (ENODEV, EIO after
// an unplug) is fatal for the caller.
func (d *Device) ReadKeys() ([keyCount]bool, error) {
	buf := make([]byte, 512)
	n, err := d.f.Read(buf)
	if err != nil {
		return [keyCount]bool{}, err
	}
	if n == 0 {
		return [keyCount]bool{}, errors.New("device returned EOF")
	}
	return parseKeys(buf[:n])
}

// ioctl request numbers, from <linux/hidraw.h>.
func hidiocFeature(nr, size uintptr) uintptr {
	const iocRead, iocWrite = 2, 1
	return (iocRead|iocWrite)<<30 | size<<16 | 'H'<<8 | nr
}

func (d *Device) feature(nr uintptr, buf []byte) error {
	rc, err := d.f.SyscallConn()
	if err != nil {
		return err
	}
	var errno syscall.Errno
	d.mu.Lock()
	defer d.mu.Unlock()
	if err := rc.Control(func(fd uintptr) {
		_, _, errno = syscall.Syscall(syscall.SYS_IOCTL, fd,
			hidiocFeature(nr, uintptr(len(buf))), uintptr(unsafe.Pointer(&buf[0])))
	}); err != nil {
		return err
	}
	if errno != 0 {
		return errno
	}
	return nil
}

func (d *Device) setFeature(b ...byte) error {
	buf := make([]byte, featureLen)
	copy(buf, b)
	return d.feature(0x06, buf) // HIDIOCSFEATURE
}

func (d *Device) getFeature(id byte) ([]byte, error) {
	buf := make([]byte, featureLen)
	buf[0] = id
	err := d.feature(0x07, buf) // HIDIOCGFEATURE
	return buf, err
}

func (d *Device) Reset() error { return d.setFeature(0x03, 0x02) }

func (d *Device) SetBrightness(pct int) error {
	return d.setFeature(0x03, 0x08, byte(max(0, min(100, pct))))
}

func cString(b []byte) string {
	if i := strings.IndexByte(string(b), 0); i >= 0 {
		b = b[:i]
	}
	return strings.TrimSpace(string(b))
}

func (d *Device) Serial() (string, error) {
	b, err := d.getFeature(0x06)
	if err != nil {
		return "", err
	}
	return cString(b[2:]), nil
}

func (d *Device) Firmware() (string, error) {
	b, err := d.getFeature(0x05)
	if err != nil {
		return "", err
	}
	return cString(b[6:]), nil
}
