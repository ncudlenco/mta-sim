ScreenshotService = class(function(o, screenshotMode)
    o.name = "ScreenshotService"
    o.mtaScreenshotHandler = nil
    o.powershellScreenshotHandler = nil
    o.nativeScreenshotHandler = nil
    o.activeHandler = nil
    o.screenshotMode = screenshotMode or "mta"
end)

function ScreenshotService:Initialize()
    self.mtaScreenshotHandler = MTAScreenshotHandler()
    self.powershellScreenshotHandler = PowerShellScreenshotHandler()
    self.nativeScreenshotHandler = NativeScreenshotHandler()

    self:SetActiveHandler(self.screenshotMode)

    if DEBUG_SCREENSHOTS then
        print("ScreenshotService: Initialized with mode: " .. self.screenshotMode)
    end
end

function ScreenshotService:SetActiveHandler(mode)
    if mode == "powershell" then
        self.activeHandler = self.powershellScreenshotHandler
    elseif mode == "native" then
        self.activeHandler = self.nativeScreenshotHandler
    else
        self.activeHandler = self.mtaScreenshotHandler
    end

    if DEBUG_SCREENSHOTS then
        print("ScreenshotService: Switched to " .. mode .. " mode")
    end
end

function ScreenshotService:TakeScreenshot(spectator, storyId)
    if not self.activeHandler then
        if DEBUG_SCREENSHOTS then
            print("ScreenshotService: No active handler available")
        end
        return false
    end

    return self.activeHandler:TakeScreenshot(spectator, storyId)
end

function ScreenshotService:GetScreenshotCount(playerId, storyId)
    if not SCREENSHOTS[playerId] or not SCREENSHOTS[playerId][storyId] then
        return 0
    end
    return SCREENSHOTS[playerId][storyId]
end

MTAScreenshotHandler = class(function(o)
    o.name = "MTAScreenshotHandler"
end)

function MTAScreenshotHandler:TakeScreenshot(spectator, storyId)
    if not spectator or not storyId then
        if DEBUG_SCREENSHOTS then
            print("MTAScreenshotHandler: Invalid spectator or storyId")
        end
        return false
    end

    local playerId = spectator:getData('id')
    local playerName = spectator.name

    if not playerId or not playerName then
        if DEBUG_SCREENSHOTS then
            print("MTAScreenshotHandler: Missing player data")
        end
        return false
    end

    local tag = playerId..';'..storyId..';'..playerName
    spectator:takeScreenShot(WIDTH_RESOLUTION, HEIGHT_RESOLUTION, tag, 75)

    if DEBUG_SCREENSHOTS then
        print("MTAScreenshotHandler: Triggered for " .. playerId)
    end

    return true
end

PowerShellScreenshotHandler = class(function(o)
    o.name = "PowerShellScreenshotHandler"
end)

function PowerShellScreenshotHandler:TakeScreenshot(spectator, storyId)
    if not spectator or not storyId then
        if DEBUG_SCREENSHOTS then
            print("PowerShellScreenshotHandler: Invalid spectator or storyId")
        end
        return false
    end

    local playerId = spectator:getData('id')
    local playerName = spectator.name

    if not playerId or not playerName then
        if DEBUG_SCREENSHOTS then
            print("PowerShellScreenshotHandler: Missing player data")
        end
        return false
    end

    if not SCREENSHOTS[playerId] then
        SCREENSHOTS[playerId] = {}
    end
    if not SCREENSHOTS[playerId][storyId] then
        SCREENSHOTS[playerId][storyId] = 0
    end

    SCREENSHOTS[playerId][storyId] = 1 + SCREENSHOTS[playerId][storyId]
    local elapsedMillis = SCREENSHOTS[playerId][storyId] * LOG_FREQUENCY

    local hours = string.format("%02.f", math.floor(elapsedMillis/3600000))
    local mins = string.format("%02.f", math.floor(elapsedMillis/60000 - (hours*60)))
    local secs = string.format("%02.f", math.floor(elapsedMillis/1000 - hours*3600 - mins *60))
    local millisecs = string.format("%03.f", math.floor(elapsedMillis - secs * 1000 - hours*3600000 - mins *60000))

    local rootFolder = 'data_out'
    if type(LOAD_FROM_GRAPH) == "string" then
        rootFolder = LOAD_FROM_GRAPH..'_out'
    end

    local fileName = hours..'-'..mins..'-'..secs..'.'..millisecs..'-'..playerName..'.png'
    local resourcePath = 'Z:\\More games\\GTA San Andreas\\MTA-SA1.6\\server\\mods\\deathmatch\\resources\\sv2l\\'
    local filePath = resourcePath..rootFolder..'/'..storyId..'/'..playerId..'/'..fileName

    -- Execute PowerShell screenshot directly on server-side with os.execute (requires ACL permission)
    local scriptPath = "take_screenshot.ps1"
    local command = 'powershell.exe -WindowStyle Hidden -Command "& \\"' .. scriptPath .. '\\" -OutputPath \\"' .. filePath .. '\\""'

    if DEBUG_SCREENSHOTS then
        print("PowerShellScreenshotHandler: Server executing: " .. command)
    end

    -- Use os.execute to run PowerShell script server-side (enabled via ACL)
    local result = os.execute(command)

    if DEBUG_SCREENSHOTS then
        print("PowerShellScreenshotHandler: Command result: " .. tostring(result) .. " for " .. playerId .. " -> " .. filePath)
    end

    return result == 0  -- os.execute returns 0 for success
end

NativeScreenshotHandler = class(function(o)
    o.name = "NativeScreenshotHandler"
    o.screenshotModule = nil
end)

function NativeScreenshotHandler:TakeScreenshot(spectator, storyId)
    if not spectator or not storyId then
        if DEBUG_SCREENSHOTS then
            print("NativeScreenshotHandler: Invalid spectator or storyId")
        end
        return false
    end

    -- Check if native screenshot functions are available globalnoly
    if DEBUG_SCREENSHOTS then
        print("NativeScreenshotHandler: Checking for native functions...")
        print("takeAsyncScreenshot type:", type(takeAsyncScreenshot))
        print("takeScreenshotSync type:", type(takeScreenshotSync))
    end

    if not takeAsyncScreenshot then
        if DEBUG_SCREENSHOTS then
            print("NativeScreenshotHandler: Native screenshot functions not available - module not loaded")
        end
        return false
    end

    local playerId = spectator:getData('id')
    local playerName = spectator.name

    if not playerId or not playerName then
        if DEBUG_SCREENSHOTS then
            print("NativeScreenshotHandler: Missing player data")
        end
        return false
    end

    if not SCREENSHOTS[playerId] then
        SCREENSHOTS[playerId] = {}
    end
    if not SCREENSHOTS[playerId][storyId] then
        SCREENSHOTS[playerId][storyId] = 0
    end

    SCREENSHOTS[playerId][storyId] = 1 + SCREENSHOTS[playerId][storyId]
    local elapsedMillis = SCREENSHOTS[playerId][storyId] * LOG_FREQUENCY

    local hours = string.format("%02.f", math.floor(elapsedMillis/3600000))
    local mins = string.format("%02.f", math.floor(elapsedMillis/60000 - (hours*60)))
    local secs = string.format("%02.f", math.floor(elapsedMillis/1000 - hours*3600 - mins *60))
    local millisecs = string.format("%03.f", math.floor(elapsedMillis - secs * 1000 - hours*3600000 - mins *60000))

    local rootFolder = 'data_out'
    if type(LOAD_FROM_GRAPH) == "string" then
        rootFolder = LOAD_FROM_GRAPH..'_out'
    end

    local fileName = hours..'-'..mins..'-'..secs..'.'..millisecs..'-'..playerName..'.png'
    local resourcePath = 'Z:\\More games\\GTA San Andreas\\MTA-SA1.6\\server\\mods\\deathmatch\\resources\\sv2l\\'
    local filePath = resourcePath..rootFolder..'/'..storyId..'/'..playerId..'/'..fileName

    -- Use native C++ module for fastest screenshot capture
    local success = takeAsyncScreenshot(filePath, "MTA: San Andreas")

    if DEBUG_SCREENSHOTS then
        print("NativeScreenshotHandler: Screenshot " .. (success and "queued" or "failed") .. " for " .. playerId .. " -> " .. filePath)
    end

    return success
end