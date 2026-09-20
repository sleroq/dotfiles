local eventtap = hs.eventtap
local event = eventtap.event

local horizontalProperties = {
  event.properties.scrollWheelEventDeltaAxis2,
  event.properties.scrollWheelEventFixedPtDeltaAxis2,
  event.properties.scrollWheelEventPointDeltaAxis2,
}

-- Keep this global so Hammerspoon does not garbage-collect and stop the event tap.
horizontalScrollFilter = eventtap.new({ event.types.scrollWheel }, function(scrollEvent)
  -- Let Shift and the original scroll event reach games and virtual machines.
  if scrollEvent:getFlags().shift then
    return false
  end

  for _, property in ipairs(horizontalProperties) do
    scrollEvent:setProperty(property, 0)
  end

  -- Pass the modified event on, preserving all vertical scroll properties.
  return false
end)

horizontalScrollFilter:start()

local keyboardLayouts = {
  ["com.apple.keylayout.US"] = "com.apple.keylayout.RussianWin",
  ["com.apple.keylayout.RussianWin"] = "com.apple.keylayout.US",
}

local layoutSwitchArmed = false

local function switchKeyboardLayout()
  local nextLayout = keyboardLayouts[hs.keycodes.currentSourceID()]

  if nextLayout then
    hs.keycodes.currentSourceID(nextLayout)
  end
end

-- Treat Control+Command as a modifier tap. Using either modifier in a regular
-- keyboard shortcut cancels the switch.
layoutSwitchFilter = eventtap.new({ event.types.flagsChanged, event.types.keyDown }, function(keyEvent)
  if keyEvent:getType() == event.types.keyDown then
    layoutSwitchArmed = false
    return false
  end

  local flags = keyEvent:getFlags()

  if flags.ctrl and flags.cmd and not flags.alt and not flags.shift and not flags.fn then
    layoutSwitchArmed = true
  elseif layoutSwitchArmed and not flags.ctrl and not flags.cmd then
    layoutSwitchArmed = false
    switchKeyboardLayout()
  elseif flags.alt or flags.shift or flags.fn then
    layoutSwitchArmed = false
  end

  return false
end)

layoutSwitchFilter:start()
