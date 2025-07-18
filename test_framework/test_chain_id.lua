-- Chain ID Tests
-- Tests for the chain ID functionality to ensure object consistency

-- Load the test framework
dofile("test_framework/test_loader.lua")

-- Test scenarios
local ChainIdTests = {}

function ChainIdTests:testSingleSofaTwoActors()
    TEST:log("=== Testing Single Sofa with Two Actors ===")

    -- Clear any existing mocks
    clearMocks()

    -- Create test players
    local player1 = createTestPlayer("actor1", "Alice")
    local player2 = createTestPlayer("actor2", "Bob")

    -- Create a test room with one sofa
    local region = TEST:createTestRegion("LivingRoom")
    local episode = TEST:createTestEpisode("TestEpisode", 0)
    region.Episode = episode

    -- Create a sofa object
    local sofa = TEST:createTestObject("sofa1", "Comfortable Sofa", "Sofa", {x = 5, y = 5, z = 0})

    -- Create a location with the sofa
    local livingRoomLocation = TEST:createTestLocation(5, 5, 0, 0, 0, "Living Room Sofa", region)

    -- Create SitDown actions for the sofa
    local sitDownAction1 = TEST:createTestAction("SitDown", player1, sofa, livingRoomLocation)
    local sitDownAction2 = TEST:createTestAction("SitDown", player2, sofa, livingRoomLocation)

    -- Add actions to location
    table.insert(livingRoomLocation.allActions, sitDownAction1)
    table.insert(livingRoomLocation.allActions, sitDownAction2)

    -- Set up episode
    episode.POI = {livingRoomLocation}
    episode.Objects = {sofa}
    episode.peds = {player1, player2}

    -- Create a simple graph with two sit events
    local graph = {
        {
            id = "event1",
            Action = "SitDown",
            Entities = {"actor1", "sofa1"},
            Location = {"LivingRoom"},
            isStartingEvent = true
        },
        {
            id = "event2",
            Action = "SitDown",
            Entities = {"actor2", "sofa1"},
            Location = {"LivingRoom"},
            isStartingEvent = true
        }
    }

    -- Mock temporal structure
    local temporal = {
        event1 = {next = nil, relations = {}},
        event2 = {next = nil, relations = {}}
    }

    -- Create required objects
    local requiredObjects = {
        {id = "sofa1", name = "Comfortable Sofa", location = "LivingRoom"}
    }

    -- Create story with GraphStory
    local story = Story({player1, player2}, 10, false)
    local graphStory = GraphStory(graph, temporal, {}, requiredObjects, {episode}, "TestStory")

    -- Initialize mapping structures
    local actionMap = {}
    local eventMap = {}
    local objectMap = {}
    local eventObjectMap = {}
    local poiMap = {}

    -- Test the mapping process
    local mappingResult = graphStory:MapObjectsActionsAndPoi(
        requiredObjects,
        episode,
        actionMap,
        eventMap,
        objectMap,
        eventObjectMap,
        poiMap
    )

    TEST:assert(mappingResult, "Mapping should succeed")
    TEST:assertNotNil(eventObjectMap["sofa1"], "Sofa should be mapped in eventObjectMap")
    TEST:assertNotNil(poiMap["event1"], "Event1 should be mapped in poiMap")
    TEST:assertNotNil(poiMap["event2"], "Event2 should be mapped in poiMap")

    -- Test that both events map to the same chain ID
    if type(eventObjectMap["sofa1"]) == "table" and #eventObjectMap["sofa1"] > 0 then
        TEST:log("EventObjectMap has chain structure")

        -- Check that there's at least one chain for the sofa
        TEST:assertGreater(#eventObjectMap["sofa1"], 0, "Should have at least one chain for sofa")

        -- Get the chain ID from the first mapping
        local chainId = eventObjectMap["sofa1"][1].chainId
        TEST:assertNotNil(chainId, "Chain ID should be set")
        TEST:log("Chain ID for sofa: " .. tostring(chainId))

        -- Test that all mappings for the same object have the same chain ID
        for i, mapping in ipairs(eventObjectMap["sofa1"]) do
            TEST:assertEqual(chainId, mapping.chainId, "All sofa mappings should have same chain ID")
        end
    end

    -- Test POI mapping chain consistency
    if type(poiMap["event1"]) == "table" and #poiMap["event1"] > 0 then
        TEST:log("POI map has chain structure")

        local event1ChainId = poiMap["event1"][1].chainId
        local event2ChainId = poiMap["event2"][1].chainId

        TEST:assertEqual(event1ChainId, event2ChainId, "Both events should map to same chain ID")
        TEST:log("Event1 chain ID: " .. tostring(event1ChainId))
        TEST:log("Event2 chain ID: " .. tostring(event2ChainId))
    end

    TEST:log("✓ Single sofa two actors test completed")
end

function ChainIdTests:testMultipleChairsKitchen()
    TEST:log("=== Testing Multiple Chairs in Kitchen ===")

    -- Clear any existing mocks
    clearMocks()

    -- Create test players
    local player1 = createTestPlayer("actor1", "Alice")
    local player2 = createTestPlayer("actor2", "Bob")

    -- Create a test kitchen
    local region = TEST:createTestRegion("Kitchen")
    local episode = TEST:createTestEpisode("KitchenEpisode", 0)
    region.Episode = episode

    -- Create table and chairs
    local table = TEST:createTestObject("table1", "Dining Table", "Table", {x = 10, y = 10, z = 0})
    local chair1 = TEST:createTestObject("chair1", "Chair", "Chair", {x = 9, y = 10, z = 0})
    local chair2 = TEST:createTestObject("chair2", "Chair", "Chair", {x = 11, y = 10, z = 0})
    local food1 = TEST:createTestObject("food1", "Sandwich", "Food", {x = 10, y = 10, z = 1})
    local food2 = TEST:createTestObject("food2", "Sandwich", "Food", {x = 10, y = 10, z = 1})

    -- Create locations for each chair
    local chairLocation1 = TEST:createTestLocation(9, 10, 0, 0, 0, "Kitchen Chair 1", region)
    local chairLocation2 = TEST:createTestLocation(11, 10, 0, 0, 0, "Kitchen Chair 2", region)

    -- Create actions
    local sitDownAction1 = TEST:createTestAction("SitDown", player1, chair1, chairLocation1)
    local sitDownAction2 = TEST:createTestAction("SitDown", player2, chair2, chairLocation2)
    local eatAction1 = TEST:createTestAction("Eat", player1, food1, chairLocation1)
    local eatAction2 = TEST:createTestAction("Eat", player2, food2, chairLocation2)
    local standUpAction1 = TEST:createTestAction("StandUp", player1, chair1, chairLocation1)
    local standUpAction2 = TEST:createTestAction("StandUp", player2, chair2, chairLocation2)

    -- Add actions to locations
    table.insert(chairLocation1.allActions, sitDownAction1)
    table.insert(chairLocation1.allActions, eatAction1)
    table.insert(chairLocation1.allActions, standUpAction1)
    table.insert(chairLocation2.allActions, sitDownAction2)
    table.insert(chairLocation2.allActions, eatAction2)
    table.insert(chairLocation2.allActions, standUpAction2)

    -- Set up episode
    episode.POI = {chairLocation1, chairLocation2}
    episode.Objects = {table, chair1, chair2, food1, food2}
    episode.peds = {player1, player2}

    -- Create a graph with simultaneous eating
    local graph = {
        {
            id = "event1",
            Action = "SitDown",
            Entities = {"actor1", "chair1"},
            Location = {"Kitchen"},
            isStartingEvent = true
        },
        {
            id = "event2",
            Action = "SitDown",
            Entities = {"actor2", "chair2"},
            Location = {"Kitchen"},
            isStartingEvent = true
        },
        {
            id = "event3",
            Action = "Eat",
            Entities = {"actor1", "food1"},
            Location = {"Kitchen"}
        },
        {
            id = "event4",
            Action = "Eat",
            Entities = {"actor2", "food2"},
            Location = {"Kitchen"}
        },
        {
            id = "event5",
            Action = "StandUp",
            Entities = {"actor1", "chair1"},
            Location = {"Kitchen"}
        },
        {
            id = "event6",
            Action = "StandUp",
            Entities = {"actor2", "chair2"},
            Location = {"Kitchen"}
        }
    }

    -- Mock temporal structure with simultaneity
    local temporal = {
        event1 = {next = "event3", relations = {"same_time_event2"}},
        event2 = {next = "event4", relations = {"same_time_event1"}},
        event3 = {next = "event5", relations = {"same_time_event4"}},
        event4 = {next = "event6", relations = {"same_time_event3"}},
        event5 = {next = nil, relations = {"same_time_event6"}},
        event6 = {next = nil, relations = {"same_time_event5"}},
        same_time_event1 = {type = "same_time"},
        same_time_event2 = {type = "same_time"},
        same_time_event3 = {type = "same_time"},
        same_time_event4 = {type = "same_time"},
        same_time_event5 = {type = "same_time"},
        same_time_event6 = {type = "same_time"}
    }

    -- Create required objects
    local requiredObjects = {
        {id = "chair1", name = "Chair", location = "Kitchen"},
        {id = "chair2", name = "Chair", location = "Kitchen"},
        {id = "food1", name = "Sandwich", location = "Kitchen"},
        {id = "food2", name = "Sandwich", location = "Kitchen"}
    }

    -- Create story with GraphStory
    local story = Story({player1, player2}, 20, false)
    local graphStory = GraphStory(graph, temporal, {}, requiredObjects, {episode}, "KitchenStory")

    -- Initialize mapping structures
    local actionMap = {}
    local eventMap = {}
    local objectMap = {}
    local eventObjectMap = {}
    local poiMap = {}

    -- Test the mapping process
    local mappingResult = graphStory:MapObjectsActionsAndPoi(
        requiredObjects,
        episode,
        actionMap,
        eventMap,
        objectMap,
        eventObjectMap,
        poiMap
    )

    TEST:assert(mappingResult, "Kitchen mapping should succeed")

    -- Test that different chairs can have different chains
    TEST:assertNotNil(eventObjectMap["chair1"], "Chair1 should be mapped")
    TEST:assertNotNil(eventObjectMap["chair2"], "Chair2 should be mapped")

    -- Test that each chair maps to a consistent chain
    if type(eventObjectMap["chair1"]) == "table" and #eventObjectMap["chair1"] > 0 then
        local chair1ChainId = eventObjectMap["chair1"][1].chainId
        TEST:assertNotNil(chair1ChainId, "Chair1 should have a chain ID")
        TEST:log("Chair1 chain ID: " .. tostring(chair1ChainId))
    end

    if type(eventObjectMap["chair2"]) == "table" and #eventObjectMap["chair2"] > 0 then
        local chair2ChainId = eventObjectMap["chair2"][1].chainId
        TEST:assertNotNil(chair2ChainId, "Chair2 should have a chain ID")
        TEST:log("Chair2 chain ID: " .. tostring(chair2ChainId))
    end

    -- Test POI mapping
    TEST:assertNotNil(poiMap["event1"], "Event1 should be mapped to POI")
    TEST:assertNotNil(poiMap["event2"], "Event2 should be mapped to POI")

    -- Test that simultaneity is preserved in mapping
    if type(poiMap["event1"]) == "table" and type(poiMap["event2"]) == "table" then
        TEST:log("Both events have POI mappings with chain structure")

        -- Events should map to different locations since they use different chairs
        local event1PoiId = poiMap["event1"][1].value
        local event2PoiId = poiMap["event2"][1].value

        TEST:log("Event1 POI: " .. tostring(event1PoiId))
        TEST:log("Event2 POI: " .. tostring(event2PoiId))

        -- They should map to different POIs since they use different chairs
        TEST:assertNotEqual(event1PoiId, event2PoiId, "Different chairs should map to different POIs")
    end

    TEST:log("✓ Multiple chairs kitchen test completed")
end

function ChainIdTests:testChainIdPropagation()
    TEST:log("=== Testing Chain ID Propagation ===")

    -- Clear any existing mocks
    clearMocks()

    -- Create test players
    local player1 = createTestPlayer("actor1", "Alice")
    local player2 = createTestPlayer("actor2", "Bob")

    -- Test chain ID assignment
    player1:setData('mappedChainId', nil)
    player2:setData('mappedChainId', nil)

    -- Create a mock location with chain ID data
    local location = TEST:createTestLocation(0, 0, 0, 0, 0, "TestLocation")
    location:setData("mappedChainId_event1", 1)

    -- Test that GetMappedEventObjectId works correctly
    local eventObjectMap = {
        ["object1"] = {
            {value = "sim_object1", chainId = 1},
            {value = "sim_object2", chainId = 2}
        }
    }

    -- Mock CURRENT_STORY
    CURRENT_STORY = {
        eventObjectMap = eventObjectMap
    }

    -- Test the helper function
    local mappedId1 = location:GetMappedEventObjectId("object1", 1)
    local mappedId2 = location:GetMappedEventObjectId("object1", 2)
    local mappedIdNil = location:GetMappedEventObjectId("object1", nil)

    TEST:assertEqual("sim_object1", mappedId1, "Should return object for chain 1")
    TEST:assertEqual("sim_object2", mappedId2, "Should return object for chain 2")
    TEST:assertNil(mappedIdNil, "Should return nil for no chain ID")

    -- Test chain ID assignment after location selection
    player1:setData('mappedChainId', nil)

    -- Simulate the chain ID assignment from location
    if player1:getData('mappedChainId') == nil then
        local chainId = location:getData("mappedChainId_event1")
        if chainId then
            player1:setData('mappedChainId', chainId)
        end
    end

    TEST:assertEqual(1, player1:getData('mappedChainId'), "Player should get chain ID from location")

    -- Test that subsequent calls use the same chain ID
    local mappedId3 = location:GetMappedEventObjectId("object1", player1:getData('mappedChainId'))
    TEST:assertEqual("sim_object1", mappedId3, "Should consistently return same object for same chain")

    TEST:log("✓ Chain ID propagation test completed")
end

function ChainIdTests:runAllTests()
    TEST:log("Running Chain ID Tests...")

    TEST:test("Single Sofa Two Actors", function()
        ChainIdTests:testSingleSofaTwoActors()
    end)

    TEST:test("Multiple Chairs Kitchen", function()
        ChainIdTests:testMultipleChairsKitchen()
    end)

    TEST:test("Chain ID Propagation", function()
        ChainIdTests:testChainIdPropagation()
    end)

    return TEST:run()
end

-- Run the tests
return ChainIdTests:runAllTests()
