-- Global Error Handler for MTA:SA Server
-- Captures all errors and terminates simulation with ERROR file

local function writeErrorFile(errorMessage, messageType, file, line)
    local errorContent = string.format(
        "ERROR DETECTED AT: %s\n\n" ..
        "Type: %s\n" ..
        "File: %s\n" ..
        "Line: %s\n" ..
        "Message:\n%s\n",
        getRealTime().timestamp,
        messageType or "unknown",
        file or "unknown",
        line or "unknown",
        errorMessage or "No error message provided"
    )

    if CURRENT_STORY == nil or CURRENT_STORY.Spectators == nil then
        outputServerLog("[ErrorHandler] No current story or spectators found, skipping ERROR file creation.")
        return
    end

    if not CURRENT_STORY.LogData then
        outputServerLog("[ErrorHandler] Log mode is not activated for the current story, skipping ERROR file creation.")
        return
    end

    for _, spectator in ipairs(CURRENT_STORY.Spectators) do
        local fileLocation = ""
        if isElement(spectator) then
            local spectatorId = spectator:getData('id')
            if spectatorId then
                fileLocation = LOAD_FROM_GRAPH..'_out/'..CURRENT_STORY.Id..'/'..spectatorId .. '/ERROR'
            else
                fileLocation = LOAD_FROM_GRAPH..'_out/'..CURRENT_STORY.Id..'/ERROR'
                errorContent = errorContent .. "\nThe client game most likely disconnected before the simulation ended."
            end
        else
            fileLocation = LOAD_FROM_GRAPH..'_out/'..CURRENT_STORY.Id..'/ERROR'
            errorContent = errorContent .. "\nThe client game most likely disconnected before the simulation ended."
        end
        local file = File(fileLocation)
        if file then                               -- check if it was successfully opened
            file:setPos(file:getSize())            -- move position to the end of the file
            file:write(errorContent)                    -- append data
            file:flush()                           -- Flush the appended data into the file.
            file:close()                           -- close the file once we're done with it
        else
            outputServerLog("[ErrorHandler] Failed to create ERROR file!")
        end
    end
end

local function endCurrentStory()
    outputServerLog("[ErrorHandler] Triggering an end of current story...")

    -- Stop current story if running
    if CURRENT_STORY then
        outputServerLog("[ErrorHandler] Stopping current story...")

        -- Check if any spectators are still connected
        local hasConnectedSpectators = false
        if CURRENT_STORY.Spectators then
            for _, spectator in ipairs(CURRENT_STORY.Spectators) do
                if isElement(spectator) then
                    hasConnectedSpectators = true
                    break
                end
            end
        end

        if not hasConnectedSpectators then
            outputServerLog("[ErrorHandler] No connected spectators found, shutting down server...")
            shutdown("Client disconnected - stopping server")
        else
            -- Normal story end with connected clients
            if CURRENT_STORY.CurrentEpisode and CURRENT_STORY.CurrentEpisode.peds then
                for _,actor in ipairs(CURRENT_STORY.CurrentEpisode.peds) do
                    if isElement(actor) then
                        EndStory(actor):Apply()
                    end
                end
            end
        end
    end
end

-- Global error handler
addEventHandler("onDebugMessage", root, function(message, level, file, line, r, g, b)
    -- Level 3 = information, 2 = warning, 1 = error, 0 = custom message
    if level == 1 or message:find("ERROR") then
        outputServerLog("[ErrorHandler] ERROR DETECTED!")
        outputServerLog(string.format("[ErrorHandler] Message: %s", message))
        outputServerLog(string.format("[ErrorHandler] File: %s, Line: %s", file or "unknown", line or "unknown"))

        -- Write ERROR file
        writeErrorFile(message, "ERROR", file, line)

        -- Shutdown simulation
        endCurrentStory()
    end
end)

outputServerLog("[ErrorHandler] Global error handler initialized")