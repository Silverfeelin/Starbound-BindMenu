require "/scripts/keybinds.lua"

-- I think i removed all of my personal customizations, but it's possible i missed something. Sorry!

bm = {}
bm.config = root.assetJson("/scripts/bindMenu.config")

bm.active = false
bm.activePosition = nil

bm.queued = function() return #bm.queueCallbacks > 0 end
bm.pauseShown = false
bm.queueCallbacks = {}

bm.defaultClock = 30
bm.clock = 0

bm.regions = {}
for i=1,bm.config.regions[1] do
  bm.regions[i] = {}
  for j=1,bm.config.regions[2] do
    bm.regions[i][j] = {}
  end
end

--[[
 I set this and the config back to the old image(plus the pixel icon for the text function) just because it's my preference.
 I personally find the new image is far too large, ugly(sorry), and takes up too much space on-screen.
 I was going to make a new image since this was meant for mcontroller position and now its tech pos, but i thought of a new way to make it work through animations, so i'm going to test that first.
]]--

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
  if bm.active and bm.countdown() then
    if queued then
      world.spawnProjectile(bm.getProjectile(bm.activePosition, true))
    else
      world.spawnProjectile(bm.getProjectile(bm.activePosition, false))
    end
  end

  if bm.active then bm.highlight() end
end

function bm.getProjectile(pos, showPause)
  local dir = ""
  -- Possible to turn the cursor into the pause icon using a similar method? Unsure how the cursor works.
  -- Maybe take a look at how picking items and such works. Rather than replacing the cursor, it appears alongside it.
  if showPause ~= true then
    -- If not making the image slightly transparent during normal use, while paused could also be useful.
    dir = "?replace;000000fe=00000000;463818fe=00000000;6d6330fe=00000000;251c0bfe=00000000;c0cecefe=00000000;edf9f9fe=00000000;d8c4a1fe=00000000;ae946ffe=00000000;705c43fe=00000000"
  end

  return "invisibleprojectile",
        pos or tech.aimPosition(),
        entity.id(),
        {0, 0},
        true,
        {
          power = 0,
          processing= "",
          damageType = "nodamage",
          universalDamage = false,
          timeToLive=0,
          actionOnReap = {
            {
              action = "particle",
              specification = {
                type = "textured",
                -- Maybe using a new image, use the replace directive to make the image slightly transparent, so you can see things behind it.
                -- This would also allow bigger images without everything in the background being blocked out
                image = "/interface/streamingvideo/icon.png?replace;ff00f6=00000000" .. dir,
                layer = "front",
                initial = "drift",
                flippable = false,
                -- Set to fullbright so it doesn't turn practically unusable while in a dark area. God that's irritating.
                fullbright = true,
                size = 1,
                light = {0, 0, 0},
                timeToLive = 0.5,
                position = {0, 0},
                destructionTime = 0
              }
            }
          }
        }
end

function bm.countdown()
  bm.clock = bm.clock - 1
  if bm.clock <= 0 then
    bm.clock = bm.defaultClock
    return true
  else
    return false
  end
end

--[[
  Binds a function to the region at [x,y]. Multiple functions can be bound to the same region.
  @param x - Horizontal region index (left to right). Should be between 1 and bm.config.regions[1].
  @param y - Vertical region index (bottom to top). Should be between 1 and bm.config.regions[2].
  @param config - Table to run through. See bind examples @ line ~315
]]
function bm.bind(x, y, config)
  if not bm.regions[x] or not bm.regions[x][y] then error("") return end
  if not config or type(config) ~= "table" then error("bm.bind - config for bm.bind not defined/invalid") return end
  -- func checks
  if config.primary and type(config.primary.func) ~= "function" then error("bm.bind - func in primary is invalid/undefined") return end
  if config.alt and type(config.alt.func) ~= "function" then error("bm.bind - func in alt is invalid/undefined") return end
  -- enabled checks
  if config.primary and type(config.primary.enabled) ~= "boolean" then config.primary.enabled = true end
  if config.alt and type(config.alt.enabled) ~= "boolean" then config.alt.enabled = true end
  table.insert(bm.regions[x][y], config)
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

  bm.clock = 0
  bm.activePosition = tech.aimPosition()
  return bm.active
end

--[[
  Calls the function(s) for the selected region, if any.
  @see bm.getRegion
]]
function bm.activate(rclick)
  -- if alt isn't defined set it to false.
  local rclick = rclick or false

  if bm.queued() then
    bm.runQueued()
    return
  end

  local selection = bm.getRegion()
  if not selection then bm.toggle(false) return end
  local res = bm.regions[selection[1]][selection[2]]

  for _,v in ipairs(res) do
    if type(v) == "table" then
      if not rclick and v.primary and v.primary.enabled then
        v.primary.func()
      elseif rclick and v.alt and v.alt.enabled then
        v.alt.func()
      end
    end
  end
end

-- Instead of a right clicking system for more(practical) functions on one region, there's also potential for a double click system.
-- For example, when queueing, if another click is done on the same region, start another queue that will run your 2nd function.
-- If second click is NOT made in the same region, continue with the first function.
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

  return {bm.activePosition[1] + halfWidth, bm.activePosition[2] + halfHeight}
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

-- This (could) be done with alot of replace directives and image editing in conjunction with getRegion.
-- Very slight, un-noticable changes to the color of each tile and changing their "highlight" using directives.
function bm.highlight()
  --[[ TODO: Figure out how to highlight without adding projectiles.
      This code is an artefact from trying to use the .animation to display
      the menu. It shouldn't be uncommented.
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
  ]]
end

--[[
  Shows the regions in /debug, as long as the tech bar is active.
]]
function bm.showRegions()
  -- Added a config option to disable showing the regions.
  if bm.config.showDebug and bm.active then
    -- This didn't work if i put them together for some reason. Maybe the config just didn't reload?
    local pos = bm.activePosition
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

-- Didn't feel like messing with the way keybinds worked.
function bm.altActivate()
bm.activate(true)
end

function coinExample(coins)
  bm.queue(function()
  local coins = coins or 100

    for i=1,coins do
      world.spawnItem("money", {tech.aimPosition()[1] + math.random(0,10), tech.aimPosition()[2] + math.random(0,8)}, math.huge)
      i = i + 1
    end

  end)
  return
end


--[[
  Creation of Keybinds for toggling and activating.
  @see `bindMenu.config`:toggle
  @see `bindMenu.config`:activate
]]
Bind.create(bm.config.toggle, bm.toggle)
Bind.create(bm.config.activate, bm.activate)
Bind.create(bm.config.altActivate, bm.altActivate)


-- Example of valid bind. for functions look @ lines 293 - 307

bm.bind(8,2,
{
  primary = {
    enabled = true,
    func = function() coinExample(20) end
  },

  alt = {
    enabled = true,
    func = coinExample
  }
})

--[[
  Load other scripts that can bind regions since the bindMenu is set up.
]]
for _,v in ipairs(bm.config.scripts) do
 require(v)
end
