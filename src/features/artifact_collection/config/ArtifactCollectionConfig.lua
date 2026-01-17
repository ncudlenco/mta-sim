--- ArtifactCollectionConfig: Configuration DTO for artifact collection system
-- Reads configuration from global variables
--
-- @classmod ArtifactCollectionConfig
-- @author Claude Code
-- @license MIT

-- Modality type enumeration
ModalityType = {
    RAW = 0,
    SEGMENTATION = 1,
    DEPTH = 2,
    NONE = -1
}

ArtifactCollectionConfig = class(function(o, options)
    options = options or {}

    o.enabled = options.enabled
    o.framesPerSecond = options.framesPerSecond
    o.outputPath = options.outputPath
    o.timeout = options.timeout
    o.widthResolution = options.widthResolution
    o.heightResolution = options.heightResolution
    o.screenshotCollectorType = options.screenshotCollectorType or "client"

    -- Native screenshot collector image export
    o.nativeScreenshotSaveImages = options.nativeScreenshotSaveImages or false
    o.nativeScreenshotImageFPS = options.nativeScreenshotImageFPS or 0
    o.nativeScreenshotImageFormat = options.nativeScreenshotImageFormat or "none"
    o.nativeScreenshotJPEGQuality = options.nativeScreenshotJPEGQuality or 95

    -- Segmentation configuration
    o.enableSegmentation = options.enableSegmentation or false
    o.segmentationSavePNG = options.segmentationSavePNG or false
    o.segmentationPNGFPS = options.segmentationPNGFPS or 0

    -- Depth configuration
    o.enableDepth = options.enableDepth or false

    -- Event frame mapping configuration
    o.enableEventFrameMapping = options.enableEventFrameMapping or false

    -- Spatial relations configuration
    o.enableSpatialRelations = options.enableSpatialRelations or false
    o.spatialRelationsFPS = options.spatialRelationsFPS or 0
    o.spatialRelationsIncludeInvisible = options.spatialRelationsIncludeInvisible or false
    o.spatialRelationsMaxDistance = options.spatialRelationsMaxDistance or 0
    o.spatialRelationsIncludeObjectRelations = options.spatialRelationsIncludeObjectRelations
    if o.spatialRelationsIncludeObjectRelations == nil then
        o.spatialRelationsIncludeObjectRelations = true  -- Default to enabled
    end

    -- Video encoding settings
    o.videoFPS = options.videoFPS or 30
    o.videoBitrate = options.videoBitrate or 5000000
end)

--- Create configuration from global variables
-- Reads from ServerGlobals.lua global variables
--
-- @return ArtifactCollectionConfig Configuration instance
function ArtifactCollectionConfig.fromGlobals()
    return ArtifactCollectionConfig({
        enabled = ARTIFACT_COLLECTION_ENABLED or false,
        framesPerSecond = ARTIFACT_FRAMES_PER_SECOND or 30,
        outputPath = ARTIFACT_OUTPUT_PATH or "data_out",
        timeout = ARTIFACT_COLLECTION_TIMEOUT or 60000,
        widthResolution = WIDTH_RESOLUTION or 480,
        heightResolution = HEIGHT_RESOLUTION or 270,
        screenshotCollectorType = SCREENSHOT_COLLECTOR_TYPE or "client",

        -- Native screenshot collector image export
        nativeScreenshotSaveImages = ARTIFACT_NATIVE_SCREENSHOT_SAVE_IMAGES or false,
        nativeScreenshotImageFPS = ARTIFACT_NATIVE_SCREENSHOT_IMAGE_FPS or 0,
        nativeScreenshotImageFormat = ARTIFACT_NATIVE_SCREENSHOT_IMAGE_FORMAT or "none",
        nativeScreenshotJPEGQuality = ARTIFACT_NATIVE_SCREENSHOT_JPEG_QUALITY or 95,

        -- Segmentation configuration
        enableSegmentation = ARTIFACT_ENABLE_SEGMENTATION or false,
        segmentationSavePNG = ARTIFACT_SEGMENTATION_SAVE_PNG or false,
        segmentationPNGFPS = ARTIFACT_SEGMENTATION_PNG_FPS or 0,

        -- Depth configuration
        enableDepth = ARTIFACT_ENABLE_DEPTH or false,

        -- Event frame mapping configuration
        enableEventFrameMapping = ARTIFACT_ENABLE_EVENT_FRAME_MAPPING or false,

        -- Spatial relations configuration
        enableSpatialRelations = ARTIFACT_ENABLE_SPATIAL_RELATIONS or false,
        spatialRelationsFPS = ARTIFACT_SPATIAL_RELATIONS_FPS or 0,
        spatialRelationsIncludeInvisible = ARTIFACT_SPATIAL_RELATIONS_INCLUDE_INVISIBLE or false,
        spatialRelationsMaxDistance = ARTIFACT_SPATIAL_RELATIONS_MAX_DISTANCE or 0,
        spatialRelationsIncludeObjectRelations = ARTIFACT_SPATIAL_RELATIONS_INCLUDE_OBJECT_RELATIONS,

        -- Video encoding settings
        videoFPS = ARTIFACT_VIDEO_FPS or 30,
        videoBitrate = ARTIFACT_VIDEO_BITRATE or 5000000
    })
end

--- Check if artifact collection is enabled
-- @return boolean True if enabled
function ArtifactCollectionConfig:isEnabled()
    return self.enabled == true
end

--- Get collection interval in milliseconds based on frames per second
-- @return number Collection interval in milliseconds
function ArtifactCollectionConfig:getCollectionInterval()
    if not self.framesPerSecond or self.framesPerSecond <= 0 then
        return 1000 / 30 -- Default to 30 FPS
    end
    return math.floor(1000 / self.framesPerSecond)
end
