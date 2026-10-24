package main

import (
	"bytes"
	"image/jpeg"
	"testing"
)

func TestImageReportsChunking(t *testing.T) {
	img := make([]byte, payloadLen*2+10)
	for i := range img {
		img[i] = byte(i % 251)
	}
	reports := imageReports(7, img)
	if len(reports) != 3 {
		t.Fatalf("got %d reports, want 3", len(reports))
	}
	wantLen := []int{payloadLen, payloadLen, 10}
	var joined []byte
	for page, r := range reports {
		if len(r) != reportLen {
			t.Fatalf("page %d: len %d, want %d", page, len(r), reportLen)
		}
		last := byte(0)
		if page == 2 {
			last = 1
		}
		n := wantLen[page]
		want := []byte{0x02, 0x07, 7, last, byte(n), byte(n >> 8), byte(page), 0}
		if !bytes.Equal(r[:headerLen], want) {
			t.Errorf("page %d header % x, want % x", page, r[:headerLen], want)
		}
		joined = append(joined, r[headerLen:headerLen+n]...)
		for _, b := range r[headerLen+n:] {
			if b != 0 {
				t.Fatalf("page %d: padding not zero", page)
			}
		}
	}
	if !bytes.Equal(joined, img) {
		t.Error("payload does not reassemble to the image")
	}
}

func TestImageReportsExactFit(t *testing.T) {
	r := imageReports(0, make([]byte, payloadLen))
	if len(r) != 1 || r[0][3] != 1 || r[0][4] != payloadLen&0xff || r[0][5] != payloadLen>>8 {
		t.Fatalf("exact-fit image: %d reports, header % x", len(r), r[0][:headerLen])
	}
}

func TestParseKeys(t *testing.T) {
	report := make([]byte, keyOffset+keyCount)
	report[0] = 0x01
	report[keyOffset+0] = 1
	report[keyOffset+14] = 1
	keys, err := parseKeys(report)
	if err != nil {
		t.Fatal(err)
	}
	for i, down := range keys {
		if want := i == 0 || i == 14; down != want {
			t.Errorf("key %d = %v, want %v", i, down, want)
		}
	}
	if _, err := parseKeys(report[:10]); err == nil {
		t.Error("short report: want error")
	}
}

func TestFeatureIoctlNumbers(t *testing.T) {
	// HIDIOCSFEATURE(32) / HIDIOCGFEATURE(32) from <linux/hidraw.h>.
	if got := hidiocFeature(0x06, 32); got != 0xC0204806 {
		t.Errorf("HIDIOCSFEATURE(32) = %#x", got)
	}
	if got := hidiocFeature(0x07, 32); got != 0xC0204807 {
		t.Errorf("HIDIOCGFEATURE(32) = %#x", got)
	}
}

func TestEncodeKeyFlipsBothAxes(t *testing.T) {
	img := Render(tile())
	img.SetRGBA(0, 0, cUrgent) // top-left marker
	for y := 0; y < 8; y++ {
		for x := 0; x < 8; x++ {
			img.SetRGBA(x, y, cUrgent)
		}
	}
	out, err := jpeg.Decode(bytes.NewReader(EncodeKey(img)))
	if err != nil {
		t.Fatal(err)
	}
	r, _, _, _ := out.At(keyPixels-3, keyPixels-3).RGBA()
	r0, _, _, _ := out.At(2, 2).RGBA()
	if r>>8 < 0xa0 || r0>>8 > 0x40 {
		t.Errorf("marker not at bottom-right after flip: br=%#x tl=%#x", r>>8, r0>>8)
	}
}

type fakeDeck struct {
	keys       map[int]int
	brightness []int
}

func (f *fakeDeck) SetBrightness(p int) error { f.brightness = append(f.brightness, p); return nil }
func (f *fakeDeck) SetKeyImage(k int, b []byte) error {
	if len(b) == 0 {
		panic("empty image")
	}
	f.keys[k]++
	return nil
}

func TestShutdownSplashPaintsEveryKey(t *testing.T) {
	f := &fakeDeck{keys: map[int]int{}}
	if err := paintSplash(f, "shutdown"); err != nil {
		t.Fatal(err)
	}
	if len(f.keys) != keyCount {
		t.Errorf("painted %d keys, want %d", len(f.keys), keyCount)
	}
	if len(f.brightness) != 1 || f.brightness[0] == 0 {
		t.Errorf("brightness calls %v: splash must stay visible", f.brightness)
	}
	if err := paintSplash(f, "nope"); err == nil {
		t.Error("unknown splash: want error")
	}
}
