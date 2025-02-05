hs.loadSpoon('Hyper')
hs.loadSpoon('Headspace'):start()

-- Load required extensions
local spaces = require("hs.spaces")
local window = require("hs.window")
local screen = require("hs.screen")

-- Check accessibility permissions
if not hs.accessibilityState() then
    hs.alert.show("Please enable Accessibility for Hammerspoon")
    hs.open("/System/Library/PreferencePanes/Security.prefPane")
end

-- Debug function to print spaces info
local function printSpacesInfo()
    local allSpaces = hs.spaces.allSpaces()
    print("All spaces:", hs.inspect(allSpaces))
    local mainScreen = hs.screen.mainScreen()
    if mainScreen then
        print("Main screen ID:", mainScreen:getUUID())
        local screenSpaces = allSpaces[mainScreen:getUUID()]
        if screenSpaces then
            print("Spaces on main screen:", hs.inspect(screenSpaces))
        else
            print("No spaces found for main screen")
        end
    else
        print("No main screen found")
    end
end

-- Print spaces info on startup
printSpacesInfo()

-- Function to execute yabai command and wait for completion
local function yabaiSync(args)
    local output, status = hs.execute("/run/current-system/sw/bin/yabai -m " .. table.concat(args, " "))
    return status, output
end

-- bundleID, global, local
Bindings = {
  {'com.agiletortoise.Drafts-OSX', 'd', {'x', 'n'}},
  {'com.apple.MobileSMS', 'q', nil},
  {'com.apple.finder', 'f', nil},
  {'com.microsoft.Outlook', 'e', nil},
  {'com.culturedcode.ThingsMac', 't', {',', '.'}},
  {'com.flexibits.cardhop.mac', nil, {'u'}},
  {'com.flexibits.fantastical2.mac', 'y', {'/'}},
  {'com.github.wez.wezterm', 'j', nil},
  {'com.goodsnoze.MacWhisper', nil, {'a'}},
  {'com.joehribar.toggl', 'r', nil},
  {'com.raycast.macos', nil, {'c', 'space'}},
  {'com.superultra.Homerow', nil, {'l'}},
  {'com.surteesstudios.Bartender', nil, {'b'}},
  {'md.obsidian', 'g', nil},
}

Hyper = spoon.Hyper

Hyper:bindHotKeys({hyperKey = {{}, 'F19'}})

hs.fnutils.each(Bindings, function(bindingTable)
  local bundleID, globalBind, localBinds = table.unpack(bindingTable)
  if globalBind then
    Hyper:bind({}, globalBind, function() hs.application.launchOrFocusByBundleID(bundleID) end)
  end
  if localBinds then
    hs.fnutils.each(localBinds, function(key)
      Hyper:bindPassThrough(key, bundleID)
    end)
  end
end)

-- provide the ability to override config per computer
if (hs.fs.displayName('./localConfig.lua')) then
  require('localConfig')
end

-- https://github.com/dmitriiminaev/Hammerspoon-HyperModal/blob/master/.hammerspoon/yabai.lua
local yabai = function(args, completion)
  local yabai_output = ""
  local yabai_error  = ""
  -- Runs in background very fast
  local yabai_task = hs.task.new("/run/current-system/sw/bin/yabai", function(err, stdout, stderr)
    print()
  end, function(task, stdout, stderr)
      -- print("stdout:"..stdout, "stderr:"..stderr)
      if stdout ~= nil then
        yabai_output = yabai_output .. stdout
      end
      if stderr ~= nil then
        yabai_error = yabai_error .. stderr
      end
      return true
    end, args)
  if type(completion) == "function" then
    yabai_task:setCallback(function()
      completion(yabai_output, yabai_error/run/current-system/sw/bin/yabai)
    end)
  end
  yabai_task:start()
end

-- window bindings via yabai above
-- we are using jankyborders to highlight which is focused
-- Window management bindings using yabai
--
-- Focus window in direction:
--   Ctrl + h/j/k/l: left/down/up/right
-- Swap window in direction:
--   Shift + h/j/k/l: left/down/up/right
-- Warp window in direction (move mouse to window):
--   Cmd + h/j/k/l: left/down/up/right
-- Toggle window split type:
--   Shift + x: toggle split
-- Toggle window zoom parent:
--   Shift + z: toggle zoom parent
-- Toggle window float:
--   Shift + f: toggle float
-- Set window ratio to:
--   Shift + u/i/o/p: 0.3/0.5/0.7/0.8
-- Toggle space layout between bsp and stack:
--   Shift + space: toggle space layout
-- Focus recent display:
--   Shift + tab: focus recent display
-- Focus window in direction: Ctrl + h/j/k/l: left/down/up/right
Hyper
:bind({"control"}, "h", function()
  yabai({"-m", "window", "--focus", "west"})
end)
:bind({"control"}, "j", function()
  yabai({"-m", "window", "--focus", "south"})
end)
:bind({"control"}, "k", function()
  yabai({"-m", "window", "--focus", "north"})
end)
:bind({"control"}, "l", function()
  yabai({"-m", "window", "--focus", "east"})
end)
-- Swap window in direction: Shift + h/j/k/l: left/down/up/right
:bind({"shift"}, "h", function()
  yabai({"-m", "window", "--swap", "west"})
end)
:bind({"shift"}, "j", function()
  yabai({"-m", "window", "--swap", "south"})
end)
:bind({"shift"}, "k", function()
  yabai({"-m", "window", "--swap", "north"})
end)
:bind({"shift"}, "l", function()
  yabai({"-m", "window", "--swap", "east"})
end)
-- Warp window in direction (move mouse to window): Cmd + h/j/k/l: left/down/up/right
:bind({"cmd"}, "h", function()
  yabai({"-m", "window", "--warp", "west"})
end)
:bind({"cmd"}, "j", function()
  yabai({"-m", "window", "--warp", "south"})
end)
:bind({"cmd"}, "k", function()
  yabai({"-m", "window", "--warp", "north"})
end)
:bind({"cmd"}, "l", function()
  yabai({"-m", "window", "--warp", "east"})
end)
-- Toggle window split type: Shift + x: toggle split
:bind({"shift"}, "x", function()
  yabai({"-m", "window", "--toggle", "split"})
end)
-- Toggle window zoom parent: Shift + z: toggle zoom parent
:bind({"shift"}, "z", function()
  yabai({"-m", "window", "--toggle", "zoom-parent"})
end)
-- Toggle window float: Shift + f: toggle float
:bind({"shift"}, "f", function()
  yabai({"-m", "window", "--toggle", "float"})
end)
-- Set window ratio to: Shift + u/i/o/p: 0.3/0.5/0.7/0.8
:bind({"shift"}, "u", function()
  yabai({"-m", "window", "--ratio", "abs:0.3"})
end)
:bind({"shift"}, "i", function()
  yabai({"-m", "window", "--ratio", "abs:0.5"})
end)
:bind({"shift"}, "o", function()
  yabai({"-m", "window", "--ratio", "abs:0.7"})
end)
:bind({"shift"}, "p", function()
  yabai({"-m", "window", "--ratio", "abs:0.8"})
end)
-- Toggle space layout between bsp and stack: Shift + space: toggle space layout
:bind({"shift"}, "space", function()
  if Hyper.layout and Hyper.layout == "bsp" then
    Hyper.layout = "stack"
    yabai({"-m", "space", "--layout", "stack"})
  else
    Hyper.layout = "bsp"
    yabai({"-m", "space", "--layout", "bsp"})
  end
end)
-- Focus recent display: Shift + tab: focus recent display
:bind({"shift"}, "tab", function()
  yabai({"-m", "window", "--display", "recent", "--focus"})
end)

-- Function to get space ID from index
local function getSpaceIDForIndex(screenSpaces, index)
    -- Get all spaces from yabai
    local output, status = hs.execute("/run/current-system/sw/bin/yabai -m query --spaces")
    if status and output then
        local spaces = hs.json.decode(output)
        -- Find space with matching index
        for _, space in ipairs(spaces) do
            if space.index == index then
                return space.index
            end
        end
    end
    return nil
end

-- Function to move window using both Hammerspoon and yabai
local function moveWindowToSpace(win, targetSpace)
    -- Get window ID
    local winID = win:id()
    
    -- Move window with yabai using space index
    yabaiSync({"window", tostring(winID), "--space", tostring(targetSpace)})
    
    -- Then move with Hammerspoon
    hs.spaces.moveWindowToSpace(winID, targetSpace)
    
    -- Finally, focus the space
    hs.spaces.gotoSpace(targetSpace)
end

-- Function to focus space using both Hammerspoon and yabai
local function focusSpace(targetSpace)
    -- Focus with yabai using space index
    yabaiSync({"space", "--focus", tostring(targetSpace)})
    
    -- Then focus with Hammerspoon
    hs.spaces.gotoSpace(targetSpace)
end

-- Space Navigation
for i = 1, 6 do
    -- Focus space
    Hyper:bind({}, tostring(i), function()
        if not hs.accessibilityState() then
            hs.alert.show("Please enable Accessibility for Hammerspoon")
            return
        end
        local spaces = hs.spaces.allSpaces()
        local screen = hs.screen.mainScreen()
        print("Focusing space " .. i)
        print("All spaces:", hs.inspect(spaces))
        if not screen then 
            print("No screen found")
            return 
        end
        print("Screen ID:", screen:getUUID())
        local screenSpaces = spaces[screen:getUUID()]
        if not screenSpaces then 
            print("No spaces found for screen")
            return 
        end
        print("Screen spaces:", hs.inspect(screenSpaces))
        local targetSpace = getSpaceIDForIndex(screenSpaces, i)
        if targetSpace then
            print("Moving to space " .. targetSpace)
            focusSpace(targetSpace)
        else
            print("No space found at index " .. i)
        end
    end)
    
    -- Move window to space and follow
    Hyper:bind({"shift"}, tostring(i), function()
        local win = hs.window.focusedWindow()
        print("Moving window to space " .. i)
        if not win then
            print("No focused window")
            return
        end
        local spaces = hs.spaces.allSpaces()
        local screen = hs.screen.mainScreen()
        if not screen then 
            print("No screen found")
            return 
        end
        local screenSpaces = spaces[screen:getUUID()]
        if not screenSpaces then 
            print("No spaces found for screen")
            return 
        end
        local targetSpace = getSpaceIDForIndex(screenSpaces, i)
        if targetSpace then
            print("Moving window " .. win:id() .. " to space " .. targetSpace)
            moveWindowToSpace(win, targetSpace)
        else
            print("No space found at index " .. i)
        end
    end)
end

-- Quick space navigation
-- Focus recent space: Hyper + tab
Hyper:bind({}, "tab", function() 
    local spaces = hs.spaces.allSpaces()
    local screen = hs.screen.mainScreen()
    if not screen then return end
    local screenSpaces = spaces[screen:getUUID()]
    if not screenSpaces then return end
    -- Get current space index
    local currentSpace = hs.spaces.focusedSpace()
    local currentIndex = hs.fnutils.indexOf(screenSpaces, currentSpace)
    -- Go to previous space if available
    if currentIndex and currentIndex > 1 then
        hs.spaces.gotoSpace(screenSpaces[currentIndex - 1])
    end
end)

-- Focus previous space: Hyper + [
Hyper:bind({}, "[", function()
    local spaces = hs.spaces.allSpaces()
    local screen = hs.screen.mainScreen()
    if not screen then return end
    local screenSpaces = spaces[screen:getUUID()]
    if not screenSpaces then return end
    local currentSpace = hs.spaces.focusedSpace()
    local currentIndex = hs.fnutils.indexOf(screenSpaces, currentSpace)
    if currentIndex and currentIndex > 1 then
        hs.spaces.gotoSpace(screenSpaces[currentIndex - 1])
    end
end)

-- Focus next space: Hyper + ]
Hyper:bind({}, "]", function()
    local spaces = hs.spaces.allSpaces()
    local screen = hs.screen.mainScreen()
    if not screen then return end
    local screenSpaces = spaces[screen:getUUID()]
    if not screenSpaces then return end
    local currentSpace = hs.spaces.focusedSpace()
    local currentIndex = hs.fnutils.indexOf(screenSpaces, currentSpace)
    if currentIndex and currentIndex < #screenSpaces then
        hs.spaces.gotoSpace(screenSpaces[currentIndex + 1])
    end
end)

-- Space management
-- Create space: Hyper + Shift + n
Hyper:bind({"shift"}, "n", function() yabai({"-m", "space", "--create"}) end)
-- Destroy space: Hyper + Shift + d
Hyper:bind({"shift"}, "d", function() yabai({"-m", "space", "--destroy"}) end)

-- Add reload config binding
-- Reload hammerspoon config: Hyper + R
Hyper:bind({"shift"}, "r", function()
  hs.reload()
end)

local brave = require('brave')

-- Random bindings
local chooseFromGroup = function(choice)
  local name = hs.application.nameForBundleID(choice.bundleID)

  hs.notify.new(nil)
  :title("Switching ✦-" .. choice.key .. " to " .. name)
  :contentImage(hs.image.imageFromAppBundle(choice.bundleID))
  :send()

  hs.settings.set("hyperGroup." .. choice.key, choice.bundleID)
  hs.application.launchOrFocusByBundleID(choice.bundleID)
end

local hyperGroup = function(key, group)
  Hyper:bind({}, key, nil, function()
    hs.application.launchOrFocusByBundleID(hs.settings.get("hyperGroup." .. key))
  end)
  Hyper:bind({'option'}, key, nil, function()
    print("Setting options...")
    local choices = {}
    hs.fnutils.each(group, function(bundleID)
      table.insert(choices, {
        text = hs.application.nameForBundleID(bundleID),
        image = hs.image.imageFromAppBundle(bundleID),
        bundleID = bundleID,
        key = key
      })
    end)

    if #choices == 1 then
      chooseFromGroup(choices[1])
    else
      hs.chooser.new(chooseFromGroup)
      :placeholderText("Choose an application for hyper+" .. key .. ":")
      :choices(choices)
      :show()
    end
  end)
end

hyperGroup('k', {
    'com.apple.Safari',
    'com.brave.Browser',
    'com.google.Chrome',
    'org.mozilla.firefox',
    'company.thebrowser.Browser',
    'org.mozilla.com.zen.browser'
  })

hyperGroup('i', {
    'com.microsoft.teams2'
  })

-- Jump to google hangout or zoom
Z_count = 0
Hyper:bind({}, 'z', nil, function()
  -- start a timer
  -- if not pressed again then
  if hs.application.find('us.zoom.xos') then
    hs.application.launchOrFocusByBundleID('us.zoom.xos')
  elseif hs.application.find('com.microsoft.teams2') then
    hs.application.launchOrFocusByBundleID('com.microsoft.teams2')
    local call = hs.settings.get("call")
    call:focus()
  else
    brave.jump("meet.google.com|hangouts.google.com.call")
  end
end)

-- Jump to figma
local designApps = {
  'com.figma.Desktop',
  'com.electron.realtimeboard',
  'com.adobe.LightroomClassicCC7'
}
Hyper:bind({}, 'v', nil, function()
  local appFound = hs.fnutils.find(designApps, function(bundleID)
    return hs.application.find(bundleID)
  end)

  if appFound then
    hs.application.launchOrFocusByBundleID(appFound)
  else
    brave.jump("lucidchart.com|figma.com")
  end
end)

jumpOrOpen = function(url)
  if brave.jump(url) then
    return true
  else
    hs.urlevent.openURL("https://" .. url)
  end
end

Hyper:bind({}, 'h', nil, function()
  jumpOrOpen("devdocs.io")
end)

Hyper:bind({}, 'p', nil, function()
  jumpOrOpen("chatgpt.com")
end)

-- Hyper:bind({"alt"}, 'p', nil, function()
--   jumpOrOpen("claude.ai")
-- end)

require('browserSnip')

-- change audio settings based on output
hs.audiodevice.watcher.setCallback(function(event)
  if event == "dOut" then
    local name = hs.audiodevice.defaultOutputDevice():name()
    if name == "WH-1000XM4" then
      hs.shortcuts.run("XM4")
    end
    if name == "MacBook Pro Speakers" then
      hs.shortcuts.run("Macbook Pro Speakers")
    end
  end
end)
hs.audiodevice.watcher.start()

-- Enable Spotlight support for better app name matching
hs.application.enableSpotlightForNameSearches(true)

local function focusWindowByApp(app_name)
  local cmd = string.format("/run/current-system/sw/bin/yabai -m query --windows | jq '.[] | select(.app==\"%s\") | .id'", app_name)
  local window_id = hs.execute(cmd):gsub("%s+", "")
  print(string.format("%s window ID for focus:", app_name), window_id)
  if window_id and window_id ~= "" then
      yabai({"-m", "window", window_id, "--focus"})
  end
end

-- Function to build window query for an app
local function buildWindowQuery(app_config)
    if app_config.title then
        -- Special case for Chrome windows with specific titles
        return string.format(
            "/run/current-system/sw/bin/yabai -m query --windows | " ..
            "jq '.[] | select(.app==\"%s\") | select(.title | contains(\"%s\")) | .id'",
            app_config.app, app_config.title
        )
    else
        -- Normal case - match by app name only
        return string.format(
            "/run/current-system/sw/bin/yabai -m query --windows | " ..
            "jq '.[] | select(.app==\"%s\") | .id'",
            app_config.app
        )
    end
end

-- Function to move and resize a window using yabai
local function moveAndResizeWindow(app_config, x, y, w, h)
    -- Try to launch the app if it's not running
    local app = hs.application.find(app_config.app)
    if not app then
        print("App not running, attempting to launch:", app_config.app)
        app = hs.application.open(app_config.app)
        -- Wait for app to launch and create its window
        if app then
            local max_attempts = 20  -- Increase max attempts
            local attempts = 0
            while attempts < max_attempts do
                local win = app:mainWindow()
                if win then
                    -- Move to second display immediately after window creation
                    local screen = hs.screen.allScreens()[2]
                    if screen then
                        win:moveToScreen(screen)
                        break
                    end
                end
                hs.timer.usleep(500000)  -- Wait 0.5 seconds
                attempts = attempts + 1
            end
            -- Give the window a bit more time to settle
            hs.timer.usleep(1000000)  -- Wait 1 second
        end
    end
    
    -- Try to get the window again after launch/wait
    if app then
        local win = app:mainWindow()
        if win then
            local screen = hs.screen.allScreens()[2]
            if screen then
                win:moveToScreen(screen)
            end
        end
    end
    
    local query_cmd = buildWindowQuery(app_config)
    local window_id = hs.execute(query_cmd):gsub("%s+", "")
    print("Window ID:", window_id)
    
    -- Try to get the window using Hammerspoon
    local win = window_id and hs.window.get(tonumber(window_id))
    if not win and app then
        win = app:mainWindow()
    end
    
    if win then
        -- Get the second screen
        local screen = hs.screen.allScreens()[2]
        if screen then
            -- Move window to screen first
            win:moveToScreen(screen)
            -- Get screen frame
            local frame = screen:frame()
            -- Calculate new frame
            local newFrame = {
                x = frame.x + (frame.w * x),
                y = frame.y + (frame.h * y),
                w = frame.w * w,
                h = frame.h * h
            }
            -- Set window frame
            win:setFrame(newFrame)
            -- Focus window
            win:focus()
            return
        end
    end
    
    -- If Hammerspoon approach failed, try yabai
    if window_id and window_id ~= "" then
        -- Check if window is already floating
        local status, window_info = yabaiSync({"query", "--windows", "--window", window_id})
        local is_floating = "false"
        if status then
            local info = hs.json.decode(window_info)
            is_floating = info["is-floating"] and "true" or "false"
        end
        print("Is floating:", is_floating)
        
        -- Float the window if it's not already floating
        if is_floating ~= "true" then
            yabai({"-m", "window", window_id, "--toggle", "float"})
        end
        
        -- Get display dimensions
        local status, display_output = yabaiSync({"query", "--displays"})
        print("Display output:", display_output)
        local display_info = hs.json.decode(display_output)
        
        if display_info and #display_info >= 2 then
            -- Get the second display's frame
            local frame = display_info[2].frame
            print("Frame:", hs.inspect(frame))
            -- Use the actual coordinates from yabai
            local abs_x = math.floor(frame.x + (frame.w * x))
            local abs_y = math.floor(frame.y + (frame.h * y))
            local abs_w = math.floor(frame.w * w)
            local abs_h = math.floor(frame.h * h)
            
            print(string.format("Moving window to: x=%d, y=%d, w=%d, h=%d", abs_x, abs_y, abs_w, abs_h))
            -- Move to display first
            yabaiSync({"window", window_id, "--display", "2"})
            hs.timer.usleep(100000)
            -- Set frame using absolute coordinates
            yabaiSync({"window", window_id, "--move", string.format("abs:%d:%d", abs_x, abs_y)})
            hs.timer.usleep(50000)
            yabaiSync({"window", window_id, "--resize", string.format("abs:%d:%d", abs_w, abs_h)})
        else
            print("Display info:", hs.inspect(display_info))
            print("Error: Second display not found or invalid display info")
        end
    end
end

-- Define standard position like top-right, top-left, bottom-right, bottom-left
local standardPositions = {
  center = {x = 0.2, y = 0, w = 0.6, h = 1},
  center_left = {x = 0.2, y = 0, w = 0.3, h = 1},
  center_right = {x = 0.5, y = 0, w = 0.3, h = 1},
  top_right = {x = 0.8, y = 0, w = 0.2, h = 0.495},
  top_left = {x = 0, y = 0, w = 0.2, h = 0.495},
  bottom_right = {x = 0.8, y = 0.5, w = 0.2, h = 0.495},
  bottom_left = {x = 0, y = 0.5, w = 0.2, h = 0.495}
}

-- Define position transitions for arrow keys
local positionTransitions = {
  left = {
    center = "center_left",
    center_right = "center",
    center_left = "top_left",      -- Center to corner
    top_right = "center_right",    -- Corner to center
    bottom_right = "center_right", -- Corner to center
    top_left = "top_right",        -- Stay at edge
    bottom_left = "bottom_right"   -- Stay at edge
  },
  right = {
    center_left = "center",
    center = "center_right",
    center_right = "top_right",    -- Center to corner
    top_left = "center_left",      -- Corner to center
    bottom_left = "center_left",   -- Corner to center
    top_right = "top_left",      -- Stay at edge
    bottom_right = "bottom_left" -- Stay at edge
  },
  up = {
    center = "top_left",           -- Center to corner
    center_left = "top_left",
    center_right = "top_right",
    bottom_left = "top_left",      -- Direct corner to corner
    bottom_right = "top_right",    -- Direct corner to corner
    top_left = "top_left",        -- Stay at edge
    top_right = "top_right"       -- Stay at edge
  },
  down = {
    center = "bottom_left",        -- Center to corner
    center_left = "bottom_left",
    center_right = "bottom_right",
    top_left = "bottom_left",      -- Direct corner to corner
    top_right = "bottom_right",    -- Direct corner to corner
    bottom_left = "bottom_left",  -- Stay at edge
    bottom_right = "bottom_right" -- Stay at edge
  }
}

-- Function to get current window position
local function getCurrentPosition(win)
  local frame = win:frame()
  local screen = win:screen()
  local screenFrame = screen:frame()
  
  -- Convert absolute coordinates to relative
  local relX = (frame.x - screenFrame.x) / screenFrame.w
  local relY = (frame.y - screenFrame.y) / screenFrame.h
  local relW = frame.w / screenFrame.w
  local relH = frame.h / screenFrame.h
  
  -- Find matching standard position
  for pos_name, pos in pairs(standardPositions) do
    if math.abs(pos.x - relX) < 0.1 and
        math.abs(pos.y - relY) < 0.1 and
        math.abs(pos.w - relW) < 0.1 and
        math.abs(pos.h - relH) < 0.1 then
       return pos_name
    end
  end
  return "center"  -- Default if no match found
end

-- Function to move window in specified direction
local function moveWindowInDirection(direction)
  local win = hs.window.focusedWindow()
  if win then
    local currentPos = getCurrentPosition(win)
    local nextPos = positionTransitions[direction] and positionTransitions[direction][currentPos]
    
    if nextPos then
      local app_config = {
        app = win:application():name(),
        title = win:title()
      }
      local pos = standardPositions[nextPos]
      moveAndResizeWindow(app_config, pos.x, pos.y, pos.w, pos.h)
    end
  end
end

-- Bind arrow keys with Hyper
Hyper:bind({}, "left", function() moveWindowInDirection("left") end)
Hyper:bind({}, "right", function() moveWindowInDirection("right") end)
Hyper:bind({}, "up", function() moveWindowInDirection("up") end)
Hyper:bind({}, "down", function() moveWindowInDirection("down") end)

-- Collection of apps with their default positions and sizes and their hotkeys
local apps = {
  {
    app = "Joplin",
    position = "top_right",
    hotkey = {key = "j"}
  },
  {
    app = "Google Meet",
    position = "top_left",
    hotkey = {key = "g"}
  },
  {
    app = "Google Chrome",
    title = "dfroberg (Danny Froberg)",  -- Will match any Chrome window containing "Meet"
    position = "center_right",
    hotkey = {key = "p"}
  },
  {
    app = "YouTube",
    position = "bottom_right",
    hotkey = {key = "y"}
  },
  {
    app = "Signal",
    position = "top_left",
    hotkey = {key = "s"}
  },
  {
    app = "zoom.us",
    position = "top_left",
    hotkey = {key = "z"}
  },
  {
    app = "Slack",
    position = "bottom_right",
    hotkey = {key = "a"}
  },
  {
    app = "Cursor",
    position = "center",
    hotkey = {key = "c"}
  },
  {
    app = "Obsidian",
    position = "center_right",
    hotkey = {key = "o"}
  },
  {
    app = "Gmail",
    position = "center_right",
    hotkey = {key = "m"}
  },
  {
    app = "LinkedIn",
    position = "center_right",
    hotkey = {key = "l"}
  },
  {
    app = "AWS Access Portal",
    position = "center_right",
    hotkey = {key = "w"}
  }
}

-- Ensure the apps are unmanaged, esure we use the regex to match the app name
for _, app in ipairs(apps) do
  local app_name = hs.application.nameForBundleID(app.app)
  yabaiSync({"window", "--unmanage", app_name})
end

-- Function iterate over apps collection and bind hotkeys
for _, app in ipairs(apps) do
  local mods = {"alt"}
  if app.hotkey.shift then
    table.insert(mods, "shift")
  end
  Hyper:bind(mods, app.hotkey.key, function()
    local pos = standardPositions[app.position]
    moveAndResizeWindow(app, pos.x, pos.y, pos.w, pos.h)
    focusWindowByApp(app.app)
  end)
end

-- Function to position currently focused window in a standard position
local function positionCurrentWindow(position)
  local win = hs.window.focusedWindow()
  if win then
    local app_config = {
      app = win:application():name(),
      title = win:title()
    }
    local pos = standardPositions[position]
    moveAndResizeWindow(app_config, pos.x, pos.y, pos.w, pos.h)
  end
end

-- Bind hotkey for positioning current window
Hyper:bind({"alt"}, ",", function()
  positionCurrentWindow("center_left")
end)
-- Bind hotkey for positioning current window
Hyper:bind({"alt"}, ".", function()
  positionCurrentWindow("center")
end)
-- Bind hotkey for positioning current window
Hyper:bind({"alt"}, "/", function()
  positionCurrentWindow("center_right")
end)
-- Function to check if window should be unmanaged
local function shouldUnmanage(window)
    local app = window:application()
    if app then
        local app_name = app:name()
        for _, app_config in ipairs(apps) do
            -- Add ^ to start and $ to end to make it a proper regex match
            local pattern = "^" .. app_config.app .. "$"
            if app_name:match(pattern) then
                return true
            end
        end
    end
    return false
end

-- Add window creation watcher
local window_watcher = hs.window.filter.new()
window_watcher:subscribe(hs.window.filter.windowCreated, function(window)
    if shouldUnmanage(window) then
        yabaiSync({"window", "--toggle", "float"})
    end
end)
