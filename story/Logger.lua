Logger = class(StoryTextLoggerBase, function(o, path, showOnScreen, story)
    StoryTextLoggerBase.init(o, path)
    o.ShowOnScreen = showOnScreen
    o.Story = story
    o.PhraseLinks = {". Then", ". After", ". Afterwards"}
    o.FirstPhrase = true
    o.PreviousAnd = true
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

function Logger:Log(text, ...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end

    if TIME_STAMP then
        local logText = self:GetElapsedTime().." "..text.."\n" -- with stamp
    else
        if self.FirstPhrase then -- if its the frist phrase add the skin description
            logText = text
            self.FirstPhrase = false

        else
            math.randomseed(os.time())
            dice = math.random()
            
            if dice > 0.7 and self.PreviousAnd == false then
                logText = " and" .. string.sub(text, string.len(player:getData('skinDescription')) + 1) .. ". "
                self.PreviousAnd = true
            else
                phraseLink = PickRandom(self.PhraseLinks)
                logText = phraseLink .. " " .. player:getData('gender') .. string.sub(text, string.len(player:getData('skinDescription')) + 1)
                self.PreviousAnd = false
            end
        end
    end

    if LOG_DATA then
        local file = File(self.Path)
        if file then                               -- check if it was successfully opened
            file:setPos(file:getSize())            -- move position to the end of the file
            file:write(logText)                    -- append data
            file:flush()                           -- Flush the appended data into the file.
            file:close()                           -- close the file once we're done with it
        else
            outputConsole("Unable to open "..self.Path)
        end
    end
    if self.ShowOnScreen then
        if player then
            if player.outputChat then
                player:outputChat(logText, 255, 0, 0, false)
            else
                outputChatBox(logText, 255, 0, 0, false)
            end
        end
    end
end