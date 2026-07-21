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
