package main

import (
	"bytes"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	"log"
	"os"

	"golang.org/x/image/font"
	"golang.org/x/image/font/basicfont"
	"golang.org/x/image/font/opentype"
	"golang.org/x/image/math/fixed"
)

// Glassmorphic Dark tokens (.claude/CLAUDE.md).
var (
	cBG        = rgb(0x1a1a1e)
	cSurface   = rgb(0x242428)
	cText      = rgb(0xe8e4df)
	cSecondary = rgb(0x9a9590)
	cDisabled  = rgb(0x5a5752)
	cAccent    = rgb(0xc8a67e)
	cUrgent    = rgb(0xcf6a6a)
	cSuccess   = rgb(0x7ab88a)
	cWarning   = rgb(0xd4a954)
	cInfo      = rgb(0x6fa3c7)
)

func rgb(v uint32) color.RGBA {
	return color.RGBA{uint8(v >> 16), uint8(v >> 8), uint8(v), 0xff}
}

// Text sizes, in pixels. JetBrains Mono advances 0.6em, so a 64 px usable
// width holds ~9 small, ~7 medium or ~5 large characters.
const (
	small  = 11
	medium = 14
	large  = 19
	splash = 30
)

// Line is one row of text on a tile; an empty Text is skipped.
type Line struct {
	Text  string
	Size  int
	Bold  bool
	Color color.RGBA
}

// Tile is comparable, so the UI can diff frames with ==.
type Tile struct {
	Lines  [3]Line
	Border color.RGBA // zero alpha: none
	Fill   color.RGBA // zero alpha: bg-solid
}

func label(s string) Line             { return Line{s, small, true, cSecondary} }
func big(s string, c color.RGBA) Line { return Line{s, large, true, c} }
func mid(s string, c color.RGBA) Line { return Line{s, medium, true, c} }
func note(s string, c color.RGBA) Line {
	return Line{s, small, false, c}
}

func tile(lines ...Line) Tile {
	var t Tile
	copy(t.Lines[:], lines)
	return t
}

type fonts struct {
	regular, bold []byte
	faces         map[[2]int]font.Face
}

var fontSet = loadFonts()

func loadFonts() *fonts {
	f := &fonts{faces: map[[2]int]font.Face{}}
	var err error
	f.regular, err = os.ReadFile("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf")
	if err == nil {
		f.bold, err = os.ReadFile("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf")
	}
	if err != nil {
		log.Printf("font: %v; falling back to basicfont", err)
		f.regular, f.bold = nil, nil
	}
	return f
}

func (f *fonts) face(size int, bold bool) font.Face {
	key := [2]int{size, 0}
	src := f.regular
	if bold {
		key[1], src = 1, f.bold
	}
	if face, ok := f.faces[key]; ok {
		return face
	}
	var face font.Face = basicfont.Face7x13
	if src != nil {
		if ft, err := opentype.Parse(src); err == nil {
			if ff, err := opentype.NewFace(ft, &opentype.FaceOptions{Size: float64(size), DPI: 72, Hinting: font.HintingFull}); err == nil {
				face = ff
			}
		}
	}
	f.faces[key] = face
	return face
}

// fit trims s (adding an ellipsis) until it is at most w pixels wide.
func fit(face font.Face, s string, w int) string {
	if font.MeasureString(face, s).Ceil() <= w {
		return s
	}
	r := []rune(s)
	for len(r) > 0 {
		r = r[:len(r)-1]
		if c := string(r) + "…"; font.MeasureString(face, c).Ceil() <= w {
			return c
		}
	}
	return ""
}

// drawLines centres non-empty lines vertically and horizontally inside rect.
func drawLines(img draw.Image, rect image.Rectangle, lines []Line) {
	type laid struct {
		face   font.Face
		text   string
		color  color.RGBA
		ascent int
		height int
	}
	const gap = 3
	var ls []laid
	total := 0
	for _, l := range lines {
		if l.Text == "" {
			continue
		}
		face := fontSet.face(l.Size, l.Bold)
		m := face.Metrics()
		h := (m.Ascent + m.Descent).Ceil()
		ls = append(ls, laid{face, fit(face, l.Text, rect.Dx()-6), l.Color, m.Ascent.Ceil(), h})
		total += h
	}
	if len(ls) == 0 {
		return
	}
	total += gap * (len(ls) - 1)
	y := rect.Min.Y + (rect.Dy()-total)/2
	for _, l := range ls {
		w := font.MeasureString(l.face, l.text).Ceil()
		d := font.Drawer{
			Dst:  img,
			Src:  image.NewUniform(l.color),
			Face: l.face,
			Dot:  fixed.P(rect.Min.X+(rect.Dx()-w)/2, y+l.ascent),
		}
		d.DrawString(l.text)
		y += l.height + gap
	}
}

// Render draws a tile the right way up.
func Render(t Tile) *image.RGBA {
	img := image.NewRGBA(image.Rect(0, 0, keyPixels, keyPixels))
	fill := t.Fill
	if fill.A == 0 {
		fill = cBG
	}
	draw.Draw(img, img.Bounds(), image.NewUniform(fill), image.Point{}, draw.Src)
	if t.Border.A != 0 {
		const bw = 3
		u := image.NewUniform(t.Border)
		for _, r := range []image.Rectangle{
			image.Rect(0, 0, keyPixels, bw), image.Rect(0, keyPixels-bw, keyPixels, keyPixels),
			image.Rect(0, 0, bw, keyPixels), image.Rect(keyPixels-bw, 0, keyPixels, keyPixels),
		} {
			draw.Draw(img, r, u, image.Point{}, draw.Src)
		}
	}
	drawLines(img, img.Bounds(), t.Lines[:])
	return img
}

// EncodeKey flips an upright tile on both axes (the Original V2 mounts its
// panel upside down) and encodes it as the JPEG the deck expects.
func EncodeKey(img *image.RGBA) []byte {
	b := img.Bounds()
	flipped := image.NewRGBA(b)
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			flipped.SetRGBA(b.Max.X-1-x+b.Min.X, b.Max.Y-1-y+b.Min.Y, img.RGBAAt(x, y))
		}
	}
	var buf bytes.Buffer
	_ = jpeg.Encode(&buf, flipped, &jpeg.Options{Quality: 92})
	return buf.Bytes()
}

// Splash draws one picture across the whole deck and slices it per key.
func Splash(title, sub string, accent color.RGBA) [keyCount][]byte {
	const w, h = keyCols * keyPixels, keyCount / keyCols * keyPixels
	canvas := image.NewRGBA(image.Rect(0, 0, w, h))
	draw.Draw(canvas, canvas.Bounds(), image.NewUniform(cBG), image.Point{}, draw.Src)
	drawLines(canvas, image.Rect(0, keyPixels, w, 2*keyPixels), []Line{
		{title, splash, true, accent},
	})
	drawLines(canvas, image.Rect(0, 2*keyPixels, w, h), []Line{
		{sub, medium, false, cSecondary},
	})
	var out [keyCount][]byte
	for k := range out {
		x, y := (k%keyCols)*keyPixels, (k/keyCols)*keyPixels
		key := image.NewRGBA(image.Rect(0, 0, keyPixels, keyPixels))
		draw.Draw(key, key.Bounds(), canvas, image.Pt(x, y), draw.Src)
		out[k] = EncodeKey(key)
	}
	return out
}
