-- Test Framework Core
-- This file provides the main test framework functionality

local TestFramework = {}

-- Test state
TestFramework.tests = {}
TestFramework.currentTest = nil
TestFramework.passed = 0
TestFramework.failed = 0
TestFramework.assertions = 0

-- Test logging
TestFramework.verbose = true

function TestFramework:log(message)
    if self.verbose then
        print("[TEST] " .. message)
    end
end

function TestFramework:error(message)
    print("[ERROR] " .. message)
end

function TestFramework:success(message)
    print("[SUCCESS] " .. message)
end

-- Assertion functions
function TestFramework:assert(condition, message)
    self.assertions = self.assertions + 1
    if condition then
        if message then
            self:log("✓ " .. message)
        end
        return true
    else
        local errorMsg = message or "Assertion failed"
        self:error("✗ " .. errorMsg)
        error(errorMsg)
        return false
    end
end

function TestFramework:assertEqual(expected, actual, message)
    local msg = message or string.format("Expected %s, got %s", tostring(expected), tostring(actual))
    return self:assert(expected == actual, msg)
end

function TestFramework:assertNotEqual(expected, actual, message)
    local msg = message or string.format("Expected %s to not equal %s", tostring(expected), tostring(actual))
    return self:assert(expected ~= actual, msg)
end

function TestFramework:assertNil(value, message)
    local msg = message or string.format("Expected nil, got %s", tostring(value))
    return self:assert(value == nil, msg)
end

function TestFramework:assertNotNil(value, message)
    local msg = message or string.format("Expected non-nil value, got nil")
    return self:assert(value ~= nil, msg)
end

function TestFramework:assertType(expected_type, value, message)
    local actual_type = type(value)
    local msg = message or string.format("Expected type %s, got %s", expected_type, actual_type)
    return self:assert(actual_type == expected_type, msg)
end

function TestFramework:assertGreater(actual, expected, message)
    local msg = message or string.format("Expected %s to be greater than %s", tostring(actual), tostring(expected))
    return self:assert(actual > expected, msg)
end

function TestFramework:assertLess(actual, expected, message)
    local msg = message or string.format("Expected %s to be less than %s", tostring(actual), tostring(expected))
    return self:assert(actual < expected, msg)
end

function TestFramework:assertContains(collection, item, message)
    local found = false
    for _, v in pairs(collection) do
        if v == item then
            found = true
            break
        end
    end
    local msg = message or string.format("Expected collection to contain %s", tostring(item))
    return self:assert(found, msg)
end

function TestFramework:assertTableSize(table, expected_size, message)
    local actual_size = 0
    for _ in pairs(table) do
        actual_size = actual_size + 1
    end
    local msg = message or string.format("Expected table size %d, got %d", expected_size, actual_size)
    return self:assert(actual_size == expected_size, msg)
end

-- Test definition and execution
function TestFramework:test(name, testFunc)
    table.insert(self.tests, {
        name = name,
        func = testFunc
    })
end

function TestFramework:run()
    self:log("Starting test run...")

    for _, test in ipairs(self.tests) do
        self.currentTest = test
        self:log("Running test: " .. test.name)

        local success, error = pcall(test.func)

        if success then
            self.passed = self.passed + 1
            self:success("PASSED: " .. test.name)
        else
            self.failed = self.failed + 1
            self:error("FAILED: " .. test.name .. " - " .. tostring(error))
        end
    end

    self:log("Test run complete!")
    self:log(string.format("Results: %d passed, %d failed, %d assertions", self.passed, self.failed, self.assertions))

    if self.failed > 0 then
        self:error("Some tests failed!")
        return false
    else
        self:success("All tests passed!")
        return true
    end
end

function TestFramework:setup()
    -- Override this in specific test files
end

function TestFramework:teardown()
    -- Override this in specific test files
end

-- Helper functions for creating test scenarios
function TestFramework:createTestEpisode(name, interior)
    local episode = {
        name = name or "TestEpisode",
        InteriorId = interior or 0,
        POI = {},
        Objects = {},
        peds = {},
        regionsGroup = nil,
        processedRegions = false
    }

    -- Add basic methods
    episode.Play = function(self, ...)
        self:log("Episode " .. self.name .. " started")
    end

    episode.Destroy = function(self)
        self:log("Episode " .. self.name .. " destroyed")
    end

    return episode
end

function TestFramework:createTestRegion(name, episode)
    local region = {
        name = name or "TestRegion",
        Episode = episode,
        OnPlayerHit = function(self, player)
            self:log("Player " .. player.name .. " entered region " .. self.name)
        end
    }

    return region
end

function TestFramework:createTestLocation(x, y, z, angle, interior, description, region)
    -- Mock the Location class
    local location = {
        X = x or 0,
        Y = y or 0,
        Z = z or 0,
        Angle = angle or 0,
        Interior = interior or 0,
        Description = description or "TestLocation",
        Region = region,
        isBusy = false,
        position = {x = x or 0, y = y or 0, z = z or 0},
        rotation = {x = 0, y = 0, z = angle or 0},
        allActions = {},
        PossibleActions = {},
        History = {},
        metatable = {},
        LocationId = math.random(1000, 9999),
        Episode = region and region.Episode or nil
    }

    -- Add methods
    location.getData = function(self, key)
        return self.metatable[key]
    end

    location.setData = function(self, key, value)
        self.metatable[key] = value
    end

    location.SpawnPlayerHere = function(self, player, spectate)
        if not spectate then
            self.isBusy = true
            player:setData('locationId', self.LocationId)
        end
        local z = self.Z
        if spectate then
            z = self.Z + 3
        end
        player:spawn(self.X, self.Y, z, self.Angle, player.model, self.Interior)
    end

    return location
end

function TestFramework:createTestObject(id, name, objectType, position)
    local object = {
        ObjectId = id or ("test_object_" .. math.random(1000, 9999)),
        name = name or "TestObject",
        type = objectType or "Chair",
        position = position or {x = 0, y = 0, z = 0},
        instance = nil,
        Properties = {
            Type = objectType or "Chair"
        }
    }

    return object
end

function TestFramework:createTestAction(name, performer, targetItem, nextLocation)
    local action = {
        Name = name or "TestAction",
        Performer = performer,
        TargetItem = targetItem,
        NextLocation = nextLocation,
        Prerequisites = {},
        NextAction = nil,
        ClosingAction = nil,
        IsClosingAction = false,
        id = math.random(1000, 9999),
        graphId = -1
    }

    -- Add methods
    action.Apply = function(self)
        self:log("Action " .. self.Name .. " applied")
    end

    action.GetDynamicString = function(self)
        return self.Name .. " dynamic string"
    end

    return action
end

-- Global test framework instance
TEST = TestFramework

print("Test Framework Core loaded successfully")

return TestFramework
