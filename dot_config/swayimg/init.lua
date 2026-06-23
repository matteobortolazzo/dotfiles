-- Swayimg configuration (Lua).
-- Only overrides the built-in defaults; see /usr/share/swayimg/example.lua
-- for the full default config and the complete API.
--
-- Goals:
--   1. Open one image -> browse the whole folder (prev/next).
--   2. Minimal overlay: filename + position, no EXIF clutter.
--   3. Glassmorphic Dark theming (gold accent #c8a67e on a dark base).

-- Folder navigation: when launched on a single file, pull in the other
-- images from the same directory so prev/next walks the whole folder.
swayimg.imagelist.set_order("numeric")     -- natural sort: 1,2,3,10,100
swayimg.imagelist.enable_adjacent(true)    -- THE fix for "one image at a time"

-- Text overlay: minimal. Filename top-left, index top-right, nothing else.
-- (Default theme dumps format/size/time/EXIF date/EXIF camera/scale.)
swayimg.text.set_foreground(0xffe8e4df)    -- text-primary
swayimg.text.set_background(0xbf141418)    -- bg-glass-deep (legibility pill)
swayimg.text.set_shadow(0x40000000)        -- subtle drop shadow
swayimg.text.set_padding(14)
swayimg.text.set_timeout(4)                -- fade overlay after 4s
swayimg.viewer.set_text("topleft", { "{name}" })
swayimg.viewer.set_text("topright", { "{list.index} / {list.total}" })
swayimg.viewer.set_text("bottomleft", {})  -- drop the default scale readout

-- Viewer look: dark base, loop around at the folder ends.
swayimg.viewer.set_default_scale("optimal")
swayimg.viewer.set_window_background(0xff1a1a1e)  -- bg-solid
swayimg.viewer.enable_loop(true)
swayimg.viewer.set_mark_color(0xffc8a67e)         -- accent gold
swayimg.viewer.limit_preload(2)                   -- smoother next/prev

-- Tiling-friendly: keep the image fit when niri resizes the window.
swayimg.on_window_resize(function()
  swayimg.viewer.set_fix_scale("optimal")
end)

-- Explicit, intuitive navigation keys in viewer mode.
for _, key in ipairs({ "Right", "space", "n" }) do
  swayimg.viewer.on_key(key, function() swayimg.viewer.switch_image("next") end)
end
for _, key in ipairs({ "Left", "p" }) do
  swayimg.viewer.on_key(key, function() swayimg.viewer.switch_image("prev") end)
end
swayimg.viewer.on_key("Home", function() swayimg.viewer.switch_image("first") end)
swayimg.viewer.on_key("End",  function() swayimg.viewer.switch_image("last") end)
swayimg.viewer.on_key("g",    function() swayimg.set_mode("gallery") end)
swayimg.viewer.on_key("q",    function() swayimg.exit() end)

local function basename(path)
  return path:match("[^/]+$") or path
end

-- Ctrl-p: print the current image to the default printer (needs CUPS + lp).
-- Swap `lp` for `gtklp` (AUR) if you'd rather get a dialog to pick printer/copies.
swayimg.viewer.on_key("Ctrl-p", function()
  local image = swayimg.viewer.get_image()
  os.execute(string.format("lp %q >/dev/null 2>&1 &", image.path))
  swayimg.text.set_status("Printing " .. basename(image.path))
end)

-- Delete: remove the current file from disk and drop it from the list.
swayimg.viewer.on_key("Delete", function()
  local image = swayimg.viewer.get_image()
  os.remove(image.path)
  swayimg.imagelist.remove(image.path)
  swayimg.text.set_status("Deleted " .. basename(image.path))
end)

-- Gallery (thumbnail grid) theming, matching the palette.
swayimg.gallery.set_thumb_size(200)
swayimg.gallery.set_border_color(0xffc8a67e)       -- accent gold on selection
swayimg.gallery.set_selected_color(0xff2c2c31)     -- surface-raised
swayimg.gallery.set_unselected_color(0xff1a1a1e)   -- bg-solid
swayimg.gallery.set_window_color(0xff1a1a1e)
swayimg.gallery.set_mark_color(0xffc8a67e)
swayimg.gallery.set_text("topleft", { "{name}" })
swayimg.gallery.set_text("topright", { "{list.index} / {list.total}" })
swayimg.gallery.on_key("g", function() swayimg.set_mode("viewer") end)
swayimg.gallery.on_key("q", function() swayimg.exit() end)
