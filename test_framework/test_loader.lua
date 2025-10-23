-- Test Loader
-- This file loads all required dependencies for testing

-- Set up the environment
DEBUG = true
DEBUG_VALIDATION = true
DEBUG_LOCATION_CANDIDATES = true
DEBUG_PROCESSACTIONS = true
DEBUG_PATHFINDING = true
LOAD_FROM_GRAPH = true
STATIC_CAMERA = false
FREE_ROAM = false
DISABLE_BETWEEN_POINTS_TELEPORTATION = true


-- Load core utilities
dofile("utils/class.lua")
dofile("utils/others.lua")
dofile("utils/arrayUtils.lua")

-- Load mocks first
dofile("test_framework/mta_mocks.lua")

dofile("utils/VectorUtils.lua")
dofile("utils/guid.lua")


-- Load test framework
dofile("test_framework/test_framework.lua")

-- Load APIs
dofile("api/eStoryItemType.lua")
dofile("api/IStoryItem.lua")
dofile("api/StoryActionBase.lua")
dofile("api/StoryLocationBase.lua")
dofile("api/StoryBase.lua")
dofile("api/StoryEpisodeBase.lua")
dofile("api/StoryObjectBase.lua")
dofile("api/StoryTextLoggerBase.lua")
dofile("api/StoryTimeOfDayBase.lua")
dofile("api/StoryWeatherBase.lua")
dofile("api/ActionsOrchestrator.lua")
dofile("api/CameraHandler.lua")
dofile("api/PedHandler.lua")
dofile("api/StoryActionBase.lua")

-- Load story components
dofile("story/Actions/ActionsGlobals.lua")
dofile("story/GraphStory.lua")
dofile("story/RandomStory.lua")
dofile("story/Player.lua")
dofile("story/Logger.lua")
dofile("story/TimeOfDay.lua")
dofile("story/Weather.lua")

-- Load actions
dofile("story/Actions/Move.lua")
dofile("story/Actions/SitDown.lua")
dofile("story/Actions/StandUp.lua")
dofile("story/Actions/Eat.lua")
dofile("story/Actions/Drink.lua")
dofile("story/Actions/PickUp.lua")
dofile("story/Actions/PutDown.lua")
dofile("story/Actions/Wait.lua")
dofile("story/Actions/LookAt.lua")
dofile("story/Actions/Give.lua")
dofile("story/Actions/Receive.lua")
dofile("story/Actions/HandShake.lua")
dofile("story/Actions/Hug.lua")
dofile("story/Actions/Kiss.lua")
dofile("story/Actions/Talk.lua")
dofile("story/Actions/Laugh.lua")
dofile("story/Actions/EndStory.lua")
dofile("story/Actions/EmptyAction.lua")

-- Load locations
dofile("story/Locations/Location.lua")

-- Load objects
dofile("story/Objects/Furniture.lua")
dofile("story/Objects/Chair.lua")
dofile("story/Objects/Sofa.lua")
dofile("story/Objects/Table.lua")
dofile("story/Objects/Drinks.lua")
dofile("story/Objects/Food.lua")

-- Load episodes
dofile("story/Episodes/DynamicEpisode.lua")
dofile("story/Episodes/MetaEpisode.lua")

-- Mock some global functions that might not be loaded
if not GetStory then
    function GetStory(player)
        return CURRENT_STORY
    end
end

if not BoolToStr then
    function BoolToStr(bool)
        return bool and "true" or "false"
    end
end

-- Mock global variables
CURRENT_STORY = nil
SPECTATORS = {}

print("Test Loader completed successfully")
