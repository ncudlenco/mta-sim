addCommandHandler("cmarker",
	function (commandName)
		outputDebugString("Got: "..commandName)
        local thePlayer = localPlayer
        local x = thePlayer.position.x + 3
        local y = thePlayer.position.y
        local z = thePlayer.position.z
		local marker = Marker(x, y, z, "cylinder", 1, 255, 0, 0, 128)
		marker.interior = thePlayer.interior
	end
)

addCommandHandler("visibleTextures",
    function (commandName)
        outputDebugString("Visible textures:")
        local visibleTextures = engineGetVisibleTextureNames()
        for _, texName in ipairs(visibleTextures) do
            outputDebugString(" - " .. texName)
        end
    end
)

addCommandHandler("cmarker_hide",
    function (commandName)
        local thePlayer = localPlayer
        -- get all objects of type marker
        for i, marker in ipairs(getElementsByType("marker")) do
            local dimension = getElementDimension(marker)
            outputDebugString(string.format("Marker %d: Position=(%.2f, %.2f, %.2f), Dimension=%d", i, marker.position.x, marker.position.y, marker.position.z, dimension))

            -- Move marker to another dimension which will hopefully make it invisible
            setElementDimension(marker, dimension + 1)
        end
    end
)

addCommandHandler("cmarker_show",
    function (commandName)
        local thePlayer = localPlayer
        -- get all objects of type marker
        for i, marker in ipairs(getElementsByType("marker")) do
            local dimension = getElementDimension(marker)
            outputDebugString(string.format("Marker %d: Position=(%.2f, %.2f, %.2f), Dimension=%d", i, marker.position.x, marker.position.y, marker.position.z, dimension))

            -- Move marker to another dimension which will hopefully make it invisible
            setElementDimension(marker, dimension - 1)
        end
    end
)

-- Test script for multi-modal capture
local capturing = false

addCommandHandler("startcapture", function()
    if capturing then
        outputChatBox("Already capturing!")
        return
    end

    local config = {
        -- Output path
        outputPath = "C:/temp/mta_capture/",

        -- Target resolution
        targetWidth = 1920,
        targetHeight = 1080,

        -- Video settings
        videoFPS = 30,
        videoBitrate = 15000000,

        -- RGB modality
        rgbEnabled = true,
        rgbImageFormat = "jpeg",  -- or "png"
        rgbImageFPS = 10,
        rgbJPEGQuality = 95,
        rgbSaveToVideo = true,

        -- Segmentation modality
        segmentationEnabled = true,
        segmentationImageFormat = "png",
        segmentationImageFPS = 10,
        segmentationSaveToVideo = true,

        -- Depth modality
        depthEnabled = true,
        depthImageFormat = "png",
        depthImageFPS = 10,
        depthSaveToVideo = true
    }

    -- Set callback to be notified when frames are captured
    setMultiModalCallback(function(frameNumber, mappingPath)
        outputChatBox(string.format("Frame %d captured! Mapping: %s", frameNumber, mappingPath))
    end)

    -- Start capture
    local success = beginMultiModalCapture(config)
    if success then
        outputChatBox("Multi-modal capture started! Output: " .. config.outputPath)
        capturing = true
    else
        outputChatBox("Failed to start capture!")
    end
end)

addCommandHandler("stopcapture", function()
    if not capturing then
        outputChatBox("Not capturing!")
        return
    end

    endMultiModalCapture()
    outputChatBox("Multi-modal capture stopped!")
    capturing = false
end)

addCommandHandler("checkcapture", function()
    local isCap = isMultiModalCapturing()
    outputChatBox("Currently capturing: " .. tostring(isCap))
end)