-- Export window layouts to a file that yabai can read
local layouts = {}

-- Define your layouts here (similar to what you already have)
layouts.displays = {
  main = {
    -- Main display layout information
    apps = {
    }
  },
  external = {
    -- External display layout information
    apps = {
      -- Add any specific layouts for external display
      Signal = { x = 0, y = 0, w = 0.2, h = 0.5 },
      WezTerm = { x = 0, y = 0.5, w = 0.2, h = 0.5 },
      Warp = { x = 0, y = 0.5, w = 0.2, h = 0.5 },
      Cursor = { x = 0.2, y = 0, w = 0.6, h = 1.0 },
      YouTube = { x = 0.8, y = 0, w = 0.2, h = 1.0 }
    }
  }
}

-- Function to export layouts to a file
function exportLayouts()
  local file = io.open(os.getenv("HOME") .. "/.hammerspoon/window_layouts.json", "w")
  if file then
    file:write(hs.json.encode(layouts))
    file:close()
    hs.notify.new({title="Hammerspoon", informativeText="Window layouts exported"}):send()
  end
end

-- Export layouts on script load
exportLayouts()

-- Re-export when layouts change
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "E", function()
  exportLayouts()
end)

return layouts 