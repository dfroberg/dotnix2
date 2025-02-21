-- Define position transitions for arrow keys
return {
  left = {
    -- External display transitions
    center = "center_left",
    center_right = "center",
    center_left = "top_left",      -- Center to corner
    top_right = "center_right",    -- Corner to center
    bottom_right = "center_right", -- Corner to center
    top_left = "top_left",        -- Stay at edge
    bottom_left = "bottom_left",   -- Stay at edge
    
    -- Built-in display transitions
    main_center = "main_left",
    main_right = "main_center",
    main_left = "main_left"       -- Stay at edge
  },
  right = {
    -- External display transitions
    center_left = "center",
    center = "center_right",
    center_right = "top_right",    -- Center to corner
    top_left = "center_left",      -- Corner to center
    bottom_left = "center_left",   -- Corner to center
    top_right = "top_right",      -- Stay at edge
    bottom_right = "bottom_right", -- Stay at edge
    
    -- Built-in display transitions
    main_left = "main_center",
    main_center = "main_right",
    main_right = "main_right"     -- Stay at edge
  },
  up = {
    -- External display transitions
    center = "top_left",          -- Center to corner
    center_left = "top_left",
    center_right = "top_right",
    bottom_left = "top_left",     -- Direct corner to corner
    bottom_right = "top_right",   -- Direct corner to corner
    top_left = "top_left",       -- Stay at edge
    top_right = "top_right",     -- Stay at edge
    
    -- Cross-display transitions from built-in to external
    main_center = "center",       -- Center to center
    main_left = "center_left",    -- Left to left
    main_right = "center_right"   -- Right to right
  },
  down = {
    -- External display transitions
    center = "main_center",       -- Center to center
    center_left = "main_left",    -- Left to left
    center_right = "main_right",  -- Right to right
    top_left = "bottom_left",     -- Direct corner to corner
    top_right = "bottom_right",   -- Direct corner to corner
    bottom_left = "main_left",    -- Bottom corners to built-in edges
    bottom_right = "main_right",  -- Bottom corners to built-in edges
    
    -- Built-in display positions stay put
    main_center = "main_center",
    main_left = "main_left",
    main_right = "main_right"
  }
} 