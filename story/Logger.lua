Logger = class(StoryTextLoggerBase, function(o, path, showOnScreen, story)
    StoryTextLoggerBase.init(o, path)
    o.ShowOnScreen = showOnScreen
    o.Story = story
end)

function Logger:GetElapsedTime()
    local seconds = tonumber(os.difftime(os.time(), self.Story.StartTime))
  
    if seconds <= 0 then
      return "00:00:00";
    else
      local hours = string.format("%02.f", math.floor(seconds/3600));
      local mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
      local secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
      return hours..":"..mins..":"..secs
    end
end

function Logger:DescribeObjects(objects)
    local numObjects = 1
    if #objects > 1 then
        math.random(2, #objects)
    end
    local shuffledObjects = Shuffle(objects)

    local objectsDescription = ""
    for i=1, numObjects do
        if i == 1 then
            objectsDescription = objectsDescription .. " " .. getWordPrefix(shuffledObjects[i].Description) .. " " .. shuffledObjects[i].Description
        elseif i == numObjects then
            objectsDescription = objectsDescription .. " and " .. getWordPrefix(shuffledObjects[i].Description) .. " " .. shuffledObjects[i].Description
        else
            objectsDescription = objectsDescription .. ", " .. getWordPrefix(shuffledObjects[i].Description) .. " " .. shuffledObjects[i].Description
        end
    end
    return objectsDescription
end

function Logger:Log(text, ...)
    local logText = self:GetElapsedTime().." "..text
    if LOG_DATA then
        local file = File(self.Path)
        if file then                               -- check if it was successfully opened
            file:setPos(file:getSize())            -- move position to the end of the file
            file:write(logText .."\n")                      -- append data
            file:flush()                           -- Flush the appended data into the file.
            file:close()                           -- close the file once we're done with it
        else
            outputConsole("Unable to open "..self.Path)
        end
    end
    if self.ShowOnScreen then
        local player = nil
        for i,v in ipairs(arg) do
            player = v
            break
        end
        if player then
            if player.outputChat then
                player:outputChat(logText, 255, 0, 0, false)
            else
                outputChatBox(logText, 255, 0, 0, false)
            end
        end
    end
end