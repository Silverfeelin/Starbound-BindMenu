--[[
Keybinds Library
https://github.com/Silverfeelin/Starbound-Keybinds
]]

keybinds = {
  binds = {},
  initialized = false
}

-- For every type of input, set whether it can be bound.
-- EG. Keybind "f up" equals to "up" if "f" is not bindable.
keybinds.availableInputs = {
  up = true,
  left = true,
  down = true,
  right = true,
  primaryFire = true,
  altFire = true,
  onGround = true,
  running = true,
  walking = true,
  jumping = true,
  facingDirection = true,
  liquidPercentage = true,
  position = true,
  aimPosition = true,
  aimRelative = true,
  f = true,
  g = true,
  h = true,
  -- Don't set this one to false!
  aimOffset = true
}

-- Set used to allow case-insensitive input strings.
keybinds.inputStrings = {
  up = "up",
  left = "left",
  down = "down",
  right = "right",
  primaryfire = "primaryFire",
  altfire = "altFire",
  onground = "onGround",
  running = "running",
  walking = "walking",
  jumping = "jumping",
  facingdirection = "facingDirection",
  liquidpercentage = "liquidPercentage",
  position = "position",
  aimposition = "aimPosition",
  aimrelative = "aimRelative",
  f = "f",
  g = "g",
  h = "h",
  -- Don't set this one to false!
  aimoffset = "aimOffset"
}

-- Default values, do not touch.
keybinds.input = {
  up = false, left = false, down = false, right = false,
  primaryFire = false, altFire = false,
  onGround = true, running = false, walking = false, jumping = false,
  facingDirection = 1, liquidPercentage = 0,
  position = {0, 0}, aimPosition = {0, 0}, aimOffset = {2, 2}, aimRelative = {0, 0},
  f = false, g = false, h = false
}

--[[ Finalizes Keybinds by injecting function keybinds.update in the tech's main update function.]]
function keybinds.initialize()
  if not keybinds.initialized then
    keybinds.initialized = true

    -- Compatibility 'hack' for older versions of the game; use function input rather than update to update the input values (I know, right?!).
    if input then
      local originalInput = input

      input = function(args)
        keybinds.update(args)
        return originalInput(args)
      end
    else
      local originalUpdate = update

      update = function(args)
        keybinds.update(args)
        originalUpdate(args)
      end
    end
  end
end

function keybinds.update(args)
  keybinds.updateInput(args)

  for _,bind in pairs(keybinds.binds) do
    
    runFunction = true

    -- For every bind, check every arg.
    -- If an arg does not match the current input, prevent the function for this bind from being called.
    for k,v in pairs(bind.args) do
      -- AimOffset is a (static) parameter for other input methods.
      if k ~= "aimOffset" then
        if runFunction and v ~= keybinds.input[k] then
          -- Value for this argument does not match expected value for keybind.

          if tostring(v) == "vec2" then
            -- Check if positions are within the allowed range.
            local dx = math.abs(v[1] - keybinds.input[k][1])
            local dy = math.abs(v[2] - keybinds.input[k][2])

            local offset = bind.args.aimOffset or keybinds.input.aimOffset

            if dx > offset[1] or dy > offset[2] then
              runFunction = false
            end
          else
            runFunction = false
          end
        end
      end
    end

    -- Run function if the current input matches the arguments of the bind.
    -- Disables consecutive calls unless the bind is repeatable.
    if runFunction and (bind.repeatable or not bind.executed) then
      bind.f()
      bind.executed = true
    elseif not runFunction and bind.executed then
      bind.executed = false
    end
  end
end

--[[ Updates all values that can be used by keybinds.]]
function keybinds.updateInput(args)
  local input = keybinds.input

  input.up = args.moves.up
  input.left = args.moves.left
  input.down = args.moves.down
  input.right = args.moves.right

  input.primaryFire = args.moves.primaryFire
  input.altFire = args.moves.altFire

  input.onGround = mcontroller.onGround()
  input.running = mcontroller.running()
  input.walking = mcontroller.walking()
  input.jumping = args.moves.jump
  input.facingDirection = mcontroller.facingDirection()
  input.liquidPercentage = mcontroller.liquidPercentage()

  input.position = mcontroller.position()
  input.aimPosition = tech.aimPosition()
  input.aimRelative = {
    input.aimPosition[1] - input.position[1],
    input.aimPosition[2] - input.position[2]
  }
  sb.setLogMap("player_rel", string.format("%s %s", input.aimRelative[1], input.aimRelative[2]))

  input.f = args.moves.special == 1
  input.g = args.moves.special == 2
  input.h = args.moves.special == 3
end

--[[ Returns a keybind table from the given string.
See file header for syntax and supported arguments.]]
function keybinds.stringToKeybind(s)
  args = {}

  for _,v in pairs(s:split(" ")) do
    local separator = v:find("=")
    local key = v:sub(0, separator and separator - 1 or nil):lower()

    if not keybinds.availableInputs[keybinds.inputStrings[key]] then
      sb.logInfo("Keybind argument '%s' ignored.", key)
    else
      key = keybinds.inputStrings[key]
      local valueString =  separator and v:sub(separator + 1) or ""
      
      -- Default value is true
      local value = true

      if valueString == "false" then
        value = false
      elseif valueString == valueString:match("%-?%f[%.%d]%d*%.?%d*%f[^%.%d]") then
        -- Float
        value = tonumber(valueString)
      elseif valueString == valueString:match("%-?%f[%.%d]%d*%.?%d*%f[^%.%d],%-?%f[%.%d]%d*%.?%d*%f[^%.%d]") then
        -- Vec2
        local x = tonumber(valueString:sub(0,valueString:find(",") - 1))
        local y = tonumber(valueString:sub(valueString:find(",") + 1))
        value = {x,y}

        keybinds.setVec2(value)
      end

      args[key] = value
    end
  end

  return args
end

function keybinds.setVec2(point)
  setmetatable(point, {
    __tostring = function() return "vec2" end
  })
end

-- http://lua-users.org/wiki/SplitJoin
function string:split(sep)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  self:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end


Bind = {}
Bind.__index = Bind

function Bind.create(args, f, repeatable)
  -- Creating a bind will finalize the set-up, if not done already.
  keybinds.initialize()

  local bind = {}
  setmetatable(bind, Bind)

  bind:change(args, f, repeatable)
  table.insert(keybinds.binds, bind)
  bind.active = true
  return bind
end

function Bind:change(args, f, repeatable)
  self.args = type(args) == "string" and keybinds.stringToKeybind(args) or args or self.args
  self.f = f or self.f
  if type(repeatable) ~= "nil" then self.repeatable = repeatable end
  self.executed = false

  -- Remove disabled keybinds. Set the tostring of valid tables to vec2.
  for k,v in pairs(self.args) do
    if not keybinds.availableInputs[k] then
      -- Remove disabled keybinds
      self.args[k] = nil
    elseif type(v) == "table" and #v == 2 and type(v[1]) == "number" and type(v[2]) == "number" then
      -- Convert point table tostring to vec2
      keybinds.setVec2(v)
    end
  end 
end

function Bind:swap(otherBind)
  self.f, otherBind.f = otherBind.f, self.f
end

function Bind:rebind()
  local bound = false
  for i,v in pairs(keybinds.binds) do
    if v == self then return end
  end
  table.insert(keybinds.binds, self)
  self.active = true
end

function Bind:unbind()
  self.active = false
  for i,v in pairs(keybinds.binds) do
    if v == self then
      table.remove(keybinds.binds, i)
      return
    end
  end
end

function Bind:isActive()
  return self.active
end
