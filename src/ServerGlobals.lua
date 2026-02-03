-- Disable MTA's long execution warning for the entire resource
-- This allows complex graph processing and simulation runs to complete without interruption
debug.sethook(nil)

CURRENT_STORY = nil
SCREENSHOTS = {}

MAX_ACTIONS = 10000
MAX_STORY_TIME = 3600 -- 1 hour in seconds
ANIMATION_SPEED = 2
LOG_FREQUENCY = ANIMATION_SPEED * 1000 / 30 --milliseconds / frames
WIDTH_RESOLUTION = 1920
HEIGHT_RESOLUTION = 1080

DEBUG = true
DEBUG_PROCESSACTIONS = false
DEBUG_PROCESSREGIONS = false
DEBUG_TEMPLATES = false
DEBUG_LOCATION_CANDIDATES = false
DEBUG_METAEPISODE = false
DEBUG_PATHFINDING = false
DEBUG_VALIDATION = false
DEBUG_ACTION_VALIDATION = false
DEBUG_LOGGER = false
DEBUG_SCREENSHOTS = true
-- Screenshot module debugging
if setScreenshotModuleDebug then setScreenshotModuleDebug(DEBUG_SCREENSHOTS) end
-- Screenshot capture mode: set true for VMware (captures full screen instead of window cropping)
SCREENSHOT_CAPTURE_FULL_SCREEN = false
if setCaptureFullScreen then setCaptureFullScreen(SCREENSHOT_CAPTURE_FULL_SCREEN) end
DEBUG_OBJECTS = false
DEBUG_EPISODE = false
DEBUG_ACTIONS = false
DEBUG_CHAIN_LINKED_ACTIONS = false
DEBUG_CAMERA = false
DEBUG_ACTIONS_ORCHESTRATOR = false
DEBUG_POI_ORCHESTRATION = false
--- Debug flag for spatial validation logging
DEBUG_SPATIAL = false
--- Debug flag for episode group detection and cross-group teleportation logging
DEBUG_EPISODE_GROUPS = false
DEBUG_CAMERA_VALIDATION = false   -- Enable detailed logging of camera position validation and adjustments
--- Debug flag for Wait action interaction synchronization logging
DEBUG_WAIT_SYNC = false -- Enable detailed logging of Wait polling conditions (proximity, location, interaction)

-- Artifact Collection Configuration
ARTIFACT_COLLECTION_ENABLED = false -- Enable/disable artifact collection system
ARTIFACT_FRAMES_PER_SECOND = 60 -- Frame collection rate (1, 2, 5, 10, 30 fps)
ARTIFACT_OUTPUT_PATH = "data_out" -- Base path for artifact output
ARTIFACT_COLLECTION_TIMEOUT = 10000 -- Max wait time for artifact collection (ms)
SCREENSHOT_COLLECTOR_TYPE = "native" -- Screenshot collector type: "client" or "native"

-- Multi-Modal Video Configuration (requires "native" collector type)
-- Raw (native) screenshot collector image export
ARTIFACT_NATIVE_SCREENSHOT_SAVE_IMAGES = true -- Enable individual image frame saving for raw modality
ARTIFACT_NATIVE_SCREENSHOT_IMAGE_FPS = 30 -- Frame rate for image capture (0 = disabled)
ARTIFACT_NATIVE_SCREENSHOT_IMAGE_FORMAT = "jpeg" -- Image format: "png", "jpeg", or "none"
ARTIFACT_NATIVE_SCREENSHOT_JPEG_QUALITY = 95 -- JPEG quality (0-100, only used if format is "jpeg")

-- Segmentation modality (indexed PNG export)
ARTIFACT_ENABLE_SEGMENTATION = true -- Enable segmentation map video recording
ARTIFACT_SEGMENTATION_SAVE_PNG = true -- Save segmentation frames as indexed PNG files
ARTIFACT_SEGMENTATION_PNG_FPS = 60 -- Frame rate for PNG capture (frames per second, 0 = disabled)

-- Depth modality
ARTIFACT_ENABLE_DEPTH = false -- Enable depth map video recording

-- Event frame mapping collector
ARTIFACT_ENABLE_EVENT_FRAME_MAPPING = true -- Enable event-to-frame mapping JSON generation

-- Spatial relations collector
ARTIFACT_ENABLE_SPATIAL_RELATIONS = true -- Enable spatial relations JSON collection
ARTIFACT_SPATIAL_RELATIONS_FPS = 60 -- Frame rate for spatial relations capture (0 = match global FPS)
ARTIFACT_SPATIAL_RELATIONS_INCLUDE_INVISIBLE = false -- Include objects outside FOV
ARTIFACT_SPATIAL_RELATIONS_MAX_DISTANCE = 0 -- Maximum distance to include objects (0 = unlimited)
ARTIFACT_SPATIAL_RELATIONS_INCLUDE_OBJECT_RELATIONS = true -- Include pairwise object-to-object spatial relations

-- Video encoding settings (applies to all modalities that record video)
ARTIFACT_VIDEO_FPS = 30 -- Video encoding frame rate
ARTIFACT_VIDEO_BITRATE = 15000000 -- Video encoding bitrate (15 Mbps default)

-- NOT USED --
TIME_STAMP = false
ACTORS_CROWDING_FACTOR = 0.2
MIN_ACTORS = 1
MAX_ACTORS = 1
RANDOM_ACTORS_NR = false
EXPECTED_SPECTATORS = 1
-- NOT USED --

SIMULATION_MODE = true
EXPORT_MODE = false -- Set to true to export game capabilities to JSON for multiagent system
LOG_DATA = SIMULATION_MODE and true -- Set this to true if you want to save images and logs for each episode

STATIC_CAMERA = SIMULATION_MODE
FREE_ROAM = not SIMULATION_MODE
DEFINING_EPISODES = not SIMULATION_MODE

-- Camera validation settings
ENABLE_CAMERA_VALIDATION = true  -- Enable wall-aware camera positioning with line-of-sight checks
CAMERA_WALL_OFFSET = 0.5          -- Distance (units) to offset camera from walls when adjusting position

-- Camera follow mode for cinematic continuous tracking
-- true  = Use MTA's built-in setCameraTarget() with client-side smooth interpolation
-- false = Use custom timer-based implementation with 3-layer server-side smoothing
USE_BUILTIN_CAMERA_FOLLOW = true

DISABLE_BETWEEN_POINTS_TELEPORTATION = false

LOAD_FROM_GRAPH = true
INPUT_GRAPHS = {
    -- "example/path/to/a/graph.json",
}
SPECTATORS = {}

-- ============================================================================
-- Configuration Override System
-- ============================================================================
-- Load optional config.json file to override any of the global variables above
-- This allows environment-specific configuration without modifying source code
-- Example config.json:
-- {
--   "DEBUG": false,
--   "EXPORT_MODE": true,
--   "ARTIFACT_COLLECTION_ENABLED": true,
--   "MAX_ACTIONS": 5000
-- }
local configLoader = ConfigurationLoader()
local config = configLoader:load()
if config then
    configLoader:applyToGlobals(config)
end