-- Collection of apps with their default positions and sizes and their hotkeys
return {
  {
    app = "Drafts",
    bundleID = "com.agiletortoise.Drafts-OSX",
    position = "center_right",
    hotkey = {key = "d"},
    local_keys = {"x", "n"},
    tags = {"utils"}
  },
  {
    app = "Messages",
    bundleID = "com.apple.MobileSMS",
    position = "top_left",
    hotkey = {key = "q"},
    tags = {"comms"}
  },
  {
    app = "Finder",
    bundleID = "com.apple.finder",
    position = "main_right",
    hotkey = {key = "f"},
    tags = {"utils"}
  },
  {
    app = "Outlook",
    bundleID = "com.microsoft.Outlook",
    position = "center_right",
    hotkey = {key = "e"},
    tags = {"comms", "work"}
  },
  {
    app = "Things",
    bundleID = "com.culturedcode.ThingsMac",
    position = "top_right",
    hotkey = {key = "t"},
    local_keys = {",", "."},
    tags = {"utils"}
  },
  {
    app = "Cardhop",
    bundleID = "com.flexibits.cardhop.mac",
    position = "center",
    local_keys = {"u"},
    tags = {"utils"}
  },
  {
    app = "Fantastical",
    bundleID = "com.flexibits.fantastical2.mac",
    position = "center",
    local_keys = {"/"},
    tags = {"utils"}
  },
  {
    app = "WezTerm",
    bundleID = "com.github.wez.wezterm",
    position = "center",
    hotkey = {key = "x"},
    tags = {"utils"}
  },
  {
    app = "Toggl",
    bundleID = "com.joehribar.toggl",
    position = "top_right",
    hotkey = {key = "r"},
    tags = {"utils"}
  },
  {
    app = "Homerow",
    bundleID = "com.superultra.Homerow",
    position = "center",
    local_keys = {"r"},
    tags = {"utils"}
  },
  {
    app = "Bartender",
    bundleID = "com.surteesstudios.Bartender",
    position = "center",
    local_keys = {"b"},
    tags = {"utils"}
  },
  {
    app = "Obsidian",
    bundleID = "md.obsidian",
    position = "center_right",
    hotkey = {key = "o"},
    tags = {"utils"}
  },
  {
    app = "Joplin",
    position = "center_right",
    hotkey = {key = "j"},
    tags = {"utils"}
  },
  {
    app = "Google Meet",
    position = "top_left",
    hotkey = {key = "g"},
    isPWA = true,
    tags = {"comms", "work"}
  },
  {
    app = "Safari",
    bundleID = "com.apple.Safari",
    tags = {"browsers"}
  },
  {
    app = "Brave Browser",
    bundleID = "com.brave.Browser",
    tags = {"browsers"}
  },
  {
    app = "Google Chrome",
    bundleID = "com.google.Chrome",
    title = "dfroberg (Danny Froberg)",
    position = "center_right",
    hotkey = {key = "i"},
    tags = {"browsers"}
  },
  {
    app = "Firefox",
    bundleID = "org.mozilla.firefox",
    tags = {"browsers"}
  },
  {
    app = "YouTube",
    position = "top_right",
    hotkey = {key = "y"},
    isPWA = true,
    tags = {"utils"}
  },
  {
    app = "Signal",
    position = "top_left",
    hotkey = {key = "s"},
    tags = {"comms"}
  },
  {
    app = "zoom.us",
    bundleID = "us.zoom.xos",
    position = "top_left",
    hotkey = {key = "z"},
    tags = {"comms", "work"}
  },
  {
    app = "Slack",
    position = "bottom_right",
    hotkey = {key = "a"},
    tags = {"comms", "work"}
  },
  {
    app = "Gmail",
    position = "center_right",
    hotkey = {key = "m"},
    isPWA = true,
    tags = {"comms", "work"}
  },
  {
    app = "LinkedIn",
    position = "center_right",
    hotkey = {key = "l"},
    isPWA = true,
    tags = {"work"}
  },
  {
    app = "AWS Access Portal",
    position = "center_right",
    hotkey = {key = "p"},
    isPWA = true,
    tags = {"work"}
  },
  -- devtools
  {
    app = "Cursor",
    bundleID = "com.todesktop.230313mzl4w4u92",
    position = "center",
    hotkey = {key = "c"},
    tags = {"devtools", "utils"}
  },
  {
    app = "Warp",
    bundleID = "dev.warp.Warp-Stable",
    position = "bottom_left",
    hotkey = {key = "w"},
    tags = {"devtools"}
  },
  -- Urls
  {
    app = "ChatGPT",
    position = "center_right",
    isUrl = true,
    url = "https://chat.openai.com",
    tags = {"urls"}
  },
} 