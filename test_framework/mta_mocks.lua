-- MTA Mock Framework
-- This file provides mock implementations of MTA functions for testing

-- Mock data structures
local mockPlayers = {}
local mockObjects = {}
local mockMarkers = {}
local mockTimers = {}

-- Mock player class
local MockPlayer = class(function(o, id, name)
    o.id = id
    o.name = name or "TestPlayer"
    o.model = 0
    o.position = {x = 0, y = 0, z = 0}
    o.rotation = {x = 0, y = 0, z = 0}
    o.interior = 0
    o.data = {}
    o.animations = {}
    o.alive = true
    o.health = 100
    o.matrix = {
        position = o.position,
        forward = {x = 0, y = 1, z = 0},
        up = {x = 0, y = 0, z = 1}
    }
end)

function MockPlayer:spawn(x, y, z, angle, model, interior)
    self.position = {x = x, y = y, z = z}
    self.rotation = {x = 0, y = 0, z = angle or 0}
    self.model = model or 0
    self.interior = interior or 0
    self.alive = true
    print(string.format("MockPlayer:spawn - Player %s spawned at (%.2f, %.2f, %.2f)", self.name, x, y, z))

    -- Trigger onPlayerSpawn event
    if registered_callbacks["onPlayerSpawn"] then
        for _, callback in ipairs(registered_callbacks["onPlayerSpawn"]) do
            if callback.element == self then
                -- Mock the source parameter that exists in the callback function
                source = self
                callback.handler(self)
            end
        end
    end
end

function MockPlayer:setModel(model)
    self.model = model
    print(string.format("MockPlayer:setModel - Player %s model set to %d", self.name, model))
end

function MockPlayer:setAnimation(lib, name, duration, loop, updatePosition, interruptable, freezeLastFrame)
    self.animations = {
        lib = lib,
        name = name,
        duration = duration or -1,
        loop = loop or false,
        updatePosition = updatePosition or false,
        interruptable = interruptable or false,
        freezeLastFrame = freezeLastFrame or false
    }
    if lib and name then
        print(string.format("MockPlayer:setAnimation - Player %s animation set to %s:%s", self.name, lib, name))
    else
        print(string.format("MockPlayer:setAnimation - Player %s animation cleared", self.name))
    end
end

function MockPlayer:setAnimationSpeed(name, speed)
    if self.animations then
        self.animations.speed = speed
        print(string.format("MockPlayer:setAnimationSpeed - Player %s animation speed set to %.2f", self.name, speed))
    end
end

function MockPlayer:setRotation(x, y, z, order, fixPed)
    self.rotation = {x = x or 0, y = y or 0, z = z or 0}
    print(string.format("MockPlayer:setRotation - Player %s rotation set to (%.2f, %.2f, %.2f)", self.name, x or 0, y or 0, z or 0))
end

function MockPlayer:setCameraTarget(target)
    print(string.format("MockPlayer:setCameraTarget - Player %s camera target set", self.name))
end

function MockPlayer:setData(key, value)
    self.data[key] = value
    print(string.format("MockPlayer:setData - Player %s data[%s] = %s", self.name, key, tostring(value)))
end

function MockPlayer:getData(key)
    return self.data[key]
end

function MockPlayer:setAlpha(alpha)
    self.alpha = alpha
    print(string.format("MockPlayer:setAlpha - Player %s alpha set to %.2f", self.name, alpha))
end

function MockPlayer:setGravity(gravity)
    self.gravity = gravity
    print(string.format("MockPlayer:setGravity - Player %s gravity set to %.2f", self.name, gravity))
end

function MockPlayer:removeData(key)
    self.data[key] = nil
    print(string.format("MockPlayer:removeData - Player %s data[%s] removed", self.name, key))
end

function MockPlayer:destroy()
    self.alive = false
    print(string.format("MockPlayer:destroy - Player %s destroyed", self.name))
end

-- Mock object class
local MockObject = class(function(o, id, model)
    o.id = id
    o.model = model
    o.position = {x = 0, y = 0, z = 0}
    o.rotation = {x = 0, y = 0, z = 0}
    o.data = {}
    o.collisionsEnabled = true
end)

function MockObject:setCollisionsEnabled(enabled)
    self.collisionsEnabled = enabled
    print(string.format("MockObject:setCollisionsEnabled - Object %s collisions set to %s", self.id, tostring(enabled)))
end

function MockObject:setData(key, value)
    self.data[key] = value
end

function MockObject:getData(key)
    return self.data[key]
end

function MockObject:destroy()
    self.alive = false
    print(string.format("MockObject:destroy - Object %s destroyed", self.id))
end

-- Mock marker class
local MockMarker = class(function(o, x, y, z, markerType, size, r, g, b, a)
    o.position = {x = x, y = y, z = z}
    o.markerType = markerType or "cylinder"
    o.size = size or 1.0
    o.color = {r = r or 255, g = g or 255, b = b or 255, a = a or 255}
    o.interior = 0
    o.data = {}
    o.alive = true
end)

function MockMarker:setData(key, value)
    self.data[key] = value
end

function MockMarker:getData(key)
    return self.data[key]
end

function MockMarker:destroy()
    self.alive = false
    print(string.format("MockMarker:destroy - Marker destroyed"))
end

-- Mock timer class
local MockTimer = class(function(o, callback, interval, times, ...)
    o.callback = callback
    o.interval = interval
    o.times = times or 1
    o.args = {...}
    o.alive = true
    o.executed = 0
    o.id = math.random(1000, 9999)

    -- Store in global timers table
    mockTimers[o.id] = o

    -- Execute immediately for testing purposes (can be changed to simulate async)
    o:execute()
end)

function MockTimer:execute()
    if self.alive and self.executed < self.times then
        self.executed = self.executed + 1
        print(string.format("MockTimer:execute - Timer %d executing (%d/%d)", self.id, self.executed, self.times))

        -- Call the callback with the stored arguments
        if self.callback then
            self.callback(table.unpack(self.args))
        end

        -- If we've reached the limit, destroy the timer
        if self.executed >= self.times then
            self:destroy()
        end
    end
end

function MockTimer:destroy()
    self.alive = false
    mockTimers[self.id] = nil
    print(string.format("MockTimer:destroy - Timer %d destroyed", self.id))
end

-- Mock Vector3 class
local MockVector3 = class(function(o, x, y, z)
    o.x = x or 0
    o.y = y or 0
    o.z = z or 0
    o.length = math.sqrt(x*x + y*y + z*z)
end)

function MockVector3:__add(other)
    return MockVector3(self.x + other.x, self.y + other.y, self.z + other.z)
end

function MockVector3:__sub(other)
    return MockVector3(self.x - other.x, self.y - other.y, self.z - other.z)
end

function MockVector3:__mul(scalar)
    return MockVector3(self.x * scalar, self.y * scalar, self.z * scalar)
end

function MockVector3:__tostring()
    return string.format("Vector3(%.2f, %.2f, %.2f)", self.x, self.y, self.z)
end

function MockVector3:dot(other)
    return self.x * other.x + self.y * other.y + self.z * other.z
end

function MockVector3:cross(other)
    return MockVector3(
        self.y * other.z - self.z * other.y,
        self.z * other.x - self.x * other.z,
        self.x * other.y - self.y * other.x
    )
end

function MockVector3:getNormalized()
    local len = math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
    if len == 0 then return MockVector3(0, 0, 0) end
    return MockVector3(self.x / len, self.y / len, self.z / len)
end

function MockVector3:length()
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function MockVector3:unpack()
    return {x = self.x, y = self.y, z = self.z}
end


-- Global mock functions
function Timer(callback, interval, times, ...)
    return MockTimer(callback, interval, times, ...)
end

function Vector3(x, y, z)
    return MockVector3(x, y, z)
end

Vector3 = MockVector3

function Marker(x, y, z, markerType, size, r, g, b, a)
    return MockMarker(x, y, z, markerType, size, r, g, b, a)
end

function Player(id, name)
    return MockPlayer(id, name)
end

function Object(id, model)
    return MockObject(id, model)
end

function Vehicle(model, x, y, z)
    return MockObject("vehicle_" .. tostring(math.random(1000, 9999)), model)
end

-- Mock utility functions
function outputConsole(text)
    print("[CONSOLE] " .. tostring(text))
end

function fadeCamera(player, fadeIn, time, r, g, b)
    print(string.format("fadeCamera - Player %s fade %s", player.name, fadeIn and "in" or "out"))
end

registered_callbacks = {}
function addEventHandler(eventName, element, handler)
    print(string.format("addEventHandler - Event %s registered", eventName))
    if not registered_callbacks[eventName] then
        registered_callbacks[eventName] = {}
    end
    table.insert(registered_callbacks[eventName], {element = element, handler = handler})
end

function addCommandHandler(command, handler)
    print(string.format("addCommandHandler - Command %s registered", command))
end

function getElementsByType(elementType)
    if elementType == "player" then
        return mockPlayers
    elseif elementType == "object" then
        return mockObjects
    elseif elementType == "marker" then
        return mockMarkers
    end
    return {}
end

function isElement(element)
    return element and element.alive ~= false
end

function getElementType(element)
    if element.model ~= nil then
        return "object"
    elseif element.name ~= nil then
        return "player"
    elseif element.markerType ~= nil then
        return "marker"
    end
    return "unknown"
end

function getPedStat(ped, stat)
    return 569 -- Default health stat
end

function getLocalPlayer()
    return mockPlayers[1] or MockPlayer("local_player", "LocalPlayer")
end

local function mockRandomSeed(seed)
    -- Mock implementation
end

function createTestPlayer(id, name)
    local player = MockPlayer(id, name)
    mockPlayers[id] = player
    return player
end

-- Mock getRootElement function
local mockRootElement = { type = "root" }
function getRootElement()
    return mockRootElement
end

function createTestObject(id, model)
    local object = MockObject(id, model)
    mockObjects[id] = object
    return object
end

function clearMocks()
    mockPlayers = {}
    mockObjects = {}
    mockMarkers = {}
    mockTimers = {}
end

function getMockTimers()
    return mockTimers
end

function getMockPlayers()
    return mockPlayers
end

function getMockObjects()
    return mockObjects
end

print("MTA Mock Framework loaded successfully")
