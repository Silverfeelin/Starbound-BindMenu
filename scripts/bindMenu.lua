require "/scripts/keybinds.lua"

bm = {}
bm.config = root.assetJson("/scripts/bindMenu.config")

bm.active = false
bm.queued = function() return #bm.queueCallbacks > 0 end
bm.pauseShown = false
bm.queueCallbacks = {}

bm.regions = {}
for i=1,bm.config.regions[1] do
  bm.regions[i] = {}
  for j=1,bm.config.regions[2] do
    bm.regions[i][j] = {}
  end
end

bm.imageSize = root.imageSize("/interface/streamingvideo/icon.png")
bm.imageBlockSize = { bm.imageSize[1] / 8, bm.imageSize[2] / 8 }
bm.blockSize = { bm.imageBlockSize[1] / bm.config.regions[1], bm.imageBlockSize[2] / bm.config.regions[2] }

--[[
  Inject code into update function.
  For this to work properly, this script must be required inside the init function.
]]
local oldUpdate = update
update = function(args)
  oldUpdate(args)

  bm.showRegions()

  local queued = bm.queued()
  if queued and not bm.pauseShown then
    animator.setAnimationState("menuPause", "on")
    bm.pauseShown = true
  elseif not queued and bm.pauseShown then
    animator.setAnimationState("menuPause", "off")
    bm.pauseShown = false
  end

  if bm.active then bm.highlight() end
end

--[[
  Binds a function to the region at [x,y]. Multiple functions can be bound to the same region.
  @param x - Horizontal region index (left to right). Should be between 1 and bm.config.regions[1].
  @param y - Vertical region index (bottom to top). Should be between 1 and bm.config.regions[2].
  @param func - Function to bind to the given region.
]]
function bm.bind(x, y, func)
  if not bm.regions[x] or not bm.regions[x][y] then return end
  table.insert(bm.regions[x][y], func)
end

--[[
  Toggles the tech bar.
  @param [bool=not bm.active] - Value indicating whether the bar should be shown or hidden.
  @return - Value indicating whether the bar is has been toggled on or off.
]]
function bm.toggle(bool)
  if type(bool) == "boolean" then
    bm.active = bool
  else
    bm.active = not bm.active
  end

  if bm.active then
    animator.setAnimationState("menu", "on")
    animator.setAnimationState("menuHighlight", "on")
  else
    animator.setAnimationState("menu", "off")
    animator.setAnimationState("menuHighlight", "off")
  end

  return bm.active
end

--[[
  Calls the function(s) for the selected region, if any.
  @see bm.getRegion
]]
function bm.activate()
  if bm.queued() then
    bm.runQueued()
    return
  end

  local selection = bm.getRegion()
  if selection then
    local res = bm.regions[selection[1]][selection[2]]
    for _,v in ipairs(res) do
      if type(v) == "function" then v() end
    end
    if bm.config.closeOnActivate then bm.toggle(false) end
  end
end

function bm.queue(callback)
  table.insert(bm.queueCallbacks, callback)
end

function bm.runQueued()
  if #bm.queueCallbacks > 0 then
    bm.queueCallbacks[1]()
    table.remove(bm.queueCallbacks, 1)
  end
end

--[[
  Return the corner position of the currently opened region
  @param corner - "bottomleft", "bottomright", "topleft" or "topright".
  @return - World coordinates of the corner: {x,y}, or nil if the bar isn't active.
]]
function bm.corner(corner)
  if not bm.active then return end

  corner = corner:lower()

  local width, height = bm.imageBlockSize[1], bm.imageBlockSize[2]
  local halfWidth, halfHeight = width / 2, height / 2

  if corner:find("bottom") then halfHeight = -halfHeight end
  if corner:find("left") then halfWidth = -halfWidth end

  return {mcontroller.position()[1] + halfWidth, mcontroller.position()[2] + halfHeight}
end

--[[
  Returns the selected region coordinates {x,y}, or nil if the bar isn't active or
  no region was selected.
  @return - {x,y} of region or nil.
]]
function bm.getRegion()
  if bm.active then
    local width, height = bm.imageBlockSize[1], bm.imageBlockSize[2]
    local halfWidth, halfHeight = width / 2, height / 2
    local bottomLeft = bm.corner("bottomLeft")
    local topRight = bm.corner("topRight")

    local pos = tech.aimPosition()
    local i = math.ceil((pos[1] - bottomLeft[1]) / width * bm.config.regions[1])
    local j = math.ceil((pos[2] - bottomLeft[2]) / height * bm.config.regions[2])

    if i > 0 and j > 0 then
      return bm.regions[i] and bm.regions[i][j] and {i,j} or nil
    end
  end
end

bm.prevReg = {-1,-1}
function bm.highlight()
  local reg = bm.getRegion()
  if not reg then
    bm.prevReg = {-1, -1}
    animator.setAnimationState("menuHighlight", "off")
    return
  elseif reg[1] == bm.prevReg[1] and reg[2] == bm.prevReg[2] then
    return
  end
  local x, y = reg[1], reg[2]
  bm.prevReg = reg
  local yInvert = bm.config.regions[2] - y + 1

  local highlight = bm.config.highlights[yInvert] and bm.config.highlights[yInvert][x] and true or false
  animator.setAnimationState("menuHighlight", highlight and "on" or "off")
  if highlight then
    animator.resetTransformationGroup("menuHighlight")

    local relx, rely = x-0.5-bm.config.regions[1]/2, y-0.5-bm.config.regions[2]/2

    animator.translateTransformationGroup("menuHighlight", {
      relx * bm.blockSize[1],
      rely * bm.blockSize[2]
    })
  end
end

--[[
  Shows the regions in /debug, as long as the tech bar is active.
]]
function bm.showRegions()
  if bm.active then
    local pos = mcontroller.position()
    local width, height = bm.imageBlockSize[1] / 2, bm.imageBlockSize[2] / 2

    local bottomLeft = bm.corner("bottomLeft")
    local topRight = bm.corner("topRight")

    for i=0,bm.config.regions[1] do
      world.debugLine({bottomLeft[1] + i * bm.blockSize[1], bottomLeft[2]}, {bottomLeft[1] + i * bm.blockSize[1], topRight[2]}, "green")
    end

    for i=0,bm.config.regions[2] do
      world.debugLine({bottomLeft[1], bottomLeft[2] + i * bm.blockSize[2]}, {topRight[1], bottomLeft[2] + i * bm.blockSize[2]}, "green")
    end
  end
end

-- Tech bar toggle Keybind.
Bind.create(bm.config.toggle, bm.toggle)
Bind.create(bm.config.activate, bm.activate)

-- Load other scripts that can bind regions since the bindMenu is set up.
for _,v in ipairs(bm.config.scripts) do
 require(v)
end

-- Sample region; queues a task that spawns money at the cursor on the next activation.
-- You'll probably want to remove this.
bm.bind(3,2, function()
  bm.queue(function() world.spawnItem("money", tech.aimPosition(), 100) end)
end)
